{ pkgs, ... }:
pkgs.writeShellScriptBin "gpuinfo" ''
  # Bump when the state file layout or the meaning of its entries changes, so a
  # stale file from an older version is rebuilt instead of silently feeding the
  # fast paths below with missing or wrong values.
  GPUINFO_SCRIPT_VERSION=2

  gpuinfo_file="/tmp/$UID-gpuinfo"

  AQ_DRM_DEVICES="''${AQ_DRM_DEVICES:-WLR_DRM_DEVICES}"

  tired=false
  if [[ " $* " =~ " --tired " ]]; then
    if ! state_has_line "tired"; then
      echo "tired=true" >>"''${gpuinfo_file}"
      echo "set tired flag"
    else
      echo "already set tired flag"
    fi
    echo "Nvidia GPU will not be queried if it is in suspend mode"
    echo "run --reset to reset the flag"
    exit 0
  fi

  if [[ " $* " =~ " --no-tired " ]]; then
    echo "tired=false" >>"''${gpuinfo_file}"
    echo "disabled tired flag"
    exit 0
  fi

  if [[ " $* " =~ " --emoji " ]]; then
    if ! state_has_line "GPUINFO_EMOJI"; then
      echo "export GPUINFO_EMOJI=1" >>"''${gpuinfo_file}"
      echo "set emoji flag"
    else
      echo "already set emoji flag"
    fi
    echo "run --reset to reset the flag"
    exit 0
  fi

  if [[ ! " $* " =~ " --startup " ]]; then
    gpuinfo_file="''${gpuinfo_file}$2"
  fi

  # ---------------------------------------------------------------------------
  # Fork-free helpers
  #
  # waybar re-runs this script every few seconds, so every pipeline (grep, awk,
  # sed, lspci, sensors, ...) used to show up as a burst of processes and
  # wakeups in the power profile. The helpers below read sysfs with bash
  # builtins only and publish their result through globals (NUM, TEMP, FAN,
  # POWER, CLOCK, FLOOR, FREQ, MAXFREQ, WATT, UTIL) to stay subshell-free.
  # ---------------------------------------------------------------------------

  read_num() { # $1 = file -> NUM
    NUM=""
    [[ -r $1 ]] || return 1
    local v
    v=$(<"$1") || return 1
    [[ $v =~ ^-?[0-9]+$ ]] || return 1
    NUM=$v
  }

  uW_to_W() { # $1 = microwatts -> WATT
    printf -v WATT '%d.%d' $(($1 / 1000000)) $(( ($1 % 1000000) / 1000 ))
  }

  json_escape() { # $1 = raw string -> JSONESC (safe inside a JSON string)
    # Backslashes are left alone on purpose: the tooltip is built with literal
    # "\n" two-char sequences, which are already valid JSON escapes. Real
    # newlines/tabs coming from sysfs are converted here.
    local s=$1
    s=''${s//\"/\\\"}
    s=''${s//$'\t'/\\t}
    s=''${s//$'\r'/\\r}
    s=''${s//$'\n'/\\n}
    JSONESC=$s
  }

  set_state_var() { # $1 = name, $2 = value: rewrite one line without sed -i
    local tmp="''${gpuinfo_file}.new.$$"
    ${pkgs.gnugrep}/bin/grep -vE "^$1=" "''${gpuinfo_file}" >"$tmp" || true
    printf '%s=%s\n' "$1" "$2" >>"$tmp"
    ${pkgs.coreutils}/bin/mv "$tmp" "''${gpuinfo_file}"
  }

  state_has_line() { # $1 = "KEY=VALUE" or bare key -> 0 when present in the state file
    local line
    [[ -f "''${gpuinfo_file}" ]] || return 1
    while IFS= read -r line; do
      [[ $line == "$1" || $line == "$1="* ]] && return 0
    done <"''${gpuinfo_file}"
    return 1
  }

  hwmon_temp() { # $1 = hwmon dir -> TEMP (whole degrees)
    local f
    for f in "$1"/temp1_input "$1"/temp2_input; do
      if read_num "$f"; then
        TEMP=$((NUM / 1000))
        return 0
      fi
    done
    return 1
  }

  hwmon_fan() { # $1 = hwmon dir -> FAN (rpm)
    if read_num "$1"/fan1_input; then
      FAN=$NUM
      return 0
    fi
    return 1
  }

  hwmon_power() { # $1 = hwmon dir -> POWER (W, one decimal)
    local f
    for f in "$1"/power1_average "$1"/power1_input; do
      if read_num "$f" && ((NUM > 0)); then
        uW_to_W "$NUM"
        POWER=$WATT
        return 0
      fi
    done
    return 1
  }

  cpu_hwmon() { # $1 = glob of hwmon names -> first matching dir printed
    local hw name
    for hw in /sys/class/hwmon/hwmon*; do
      [[ -r $hw/name ]] || continue
      name=$(<"$hw/name")
      case $name in
        $1)
          printf '%s' "$hw"
          return 0
          ;;
      esac
    done
    return 1
  }

  cpu_temp() { # -> TEMP (whole degrees), no lm_sensors
    local hw
    if hw=$(cpu_hwmon "k10temp* | zenpower* | cpu_thermal* | coretemp* | thinkpad* | aspeed* | scpi-hwmon*"); then
      hwmon_temp "$hw" && return 0
    fi
    if hw=$(cpu_hwmon "acpitz*"); then
      hwmon_temp "$hw" && return 0
    fi
    return 1
  }

  cpu_fan() { # -> FAN (rpm)
    local hw
    if hw=$(cpu_hwmon "k10temp* | zenpower* | thinkpad* | aspeed* | coretemp*"); then
      hwmon_fan "$hw" && return 0
    fi
    return 1
  }

  cpu_avg_freq() { # -> FREQ (MHz, mean of all policies)
    local f sum=0 n=0
    for f in /sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq; do
      if read_num "$f"; then
        sum=$((sum + NUM))
        n=$((n + 1))
      fi
    done
    ((n > 0)) || return 1
    FREQ=$((sum / n / 1000))
  }

  cpu_max_freq() { # -> MAXFREQ (MHz)
    if read_num /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq; then
      MAXFREQ=$((NUM / 1000))
      return 0
    fi
    return 1
  }

  get_utilization() { # -> UTIL (percent with one decimal)
    local -a f
    local curr_stat curr_idle prev_stat prev_idle diff_stat diff_idle total scaled
    read -r -a f < /proc/stat || return 1
    curr_stat=$((f[1] + f[2] + f[3] + f[5] + f[6] + f[7]))
    curr_idle=$((f[4]))
    if [[ -r "''${gpuinfo_file}.cpu" ]]; then
      read -r prev_stat prev_idle <"''${gpuinfo_file}.cpu"
    fi
    printf '%s %s\n' "$curr_stat" "$curr_idle" >"''${gpuinfo_file}.cpu"
    [[ -n "''${prev_stat:-}" && -n "''${prev_idle:-}" ]] || return 1
    diff_stat=$((curr_stat - prev_stat))
    diff_idle=$((curr_idle - prev_idle))
    total=$((diff_stat + diff_idle))
    ((total > 0)) || return 1
    scaled=$(( (diff_stat * 1000 + total / 2) / total ))
    printf -v UTIL '%d.%d' $((scaled / 10)) $((scaled % 10))
  }

  detect() {
    card=$(echo "''${AQ_DRM_DEVICES}" | ${pkgs.coreutils}/bin/cut -d':' -f1 | ${pkgs.coreutils}/bin/cut -d'/' -f4)
    slot_number=$(${pkgs.coreutils}/bin/ls -l /dev/dri/by-path/ | ${pkgs.gnugrep}/bin/grep "''${card}" | ${pkgs.gawk}/bin/awk -F'pci-0000:|-card' '{print $2}')
    vendor_id=$(${pkgs.pciutils}/bin/lspci -nn -s "''${slot_number}")
    declare -A vendors=(["10de"]="nvidia" ["8086"]="intel" ["1002"]="amd")
    for vendor in "''${!vendors[@]}"; do
      if [[ ''${vendor_id} == *"''${vendor}"* ]]; then
        initGPU="''${vendors[''${vendor}]}"
        break
      fi
    done
    if [[ -n ''${initGPU} ]]; then
      $0 --use "''${initGPU}" --startup
    fi
  }

  query() {
    GPUINFO_NVIDIA_ENABLE=0 GPUINFO_AMD_ENABLE=0 GPUINFO_INTEL_ENABLE=0
    echo "GPUINFO_VERSION=''${GPUINFO_SCRIPT_VERSION}" >>"''${gpuinfo_file}"
    touch "''${gpuinfo_file}"

    if ${pkgs.kmod}/bin/lsmod | ${pkgs.gnugrep}/bin/grep -q 'nouveau'; then
      echo "GPUINFO_NVIDIA_GPU=\"Linux\"" >>"''${gpuinfo_file}"
      echo "GPUINFO_NVIDIA_ENABLE=1 # Using nouveau an open-source nvidia driver" >>"''${gpuinfo_file}"
    elif command -v nvidia-smi &>/dev/null; then
      GPUINFO_NVIDIA_GPU=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader,nounits | ${pkgs.coreutils}/bin/head -n 1)
      if [[ -n "''${GPUINFO_NVIDIA_GPU}" ]]; then
        if [[ "''${GPUINFO_NVIDIA_GPU}" == *"NVIDIA-SMI has failed"* ]]; then
          echo "GPUINFO_NVIDIA_ENABLE=0 # NVIDIA-SMI has failed" >>"''${gpuinfo_file}"
        else
          NVIDIA_ADDR=$(${pkgs.pciutils}/bin/lspci | ${pkgs.gnugrep}/bin/grep -Ei "VGA|3D" | ${pkgs.gnugrep}/bin/grep -i "''${GPUINFO_NVIDIA_GPU/NVIDIA /}" | ${pkgs.coreutils}/bin/cut -d' ' -f1)
          {
            echo "NVIDIA_ADDR=\"''${NVIDIA_ADDR}\""
            echo "GPUINFO_NVIDIA_GPU=\"''${GPUINFO_NVIDIA_GPU/NVIDIA /}\""
            echo "GPUINFO_NVIDIA_ENABLE=1"
          } >>"''${gpuinfo_file}"
        fi
      fi
    fi

    if ${pkgs.pciutils}/bin/lspci -nn | ${pkgs.gnugrep}/bin/grep -E "(VGA|3D)" | ${pkgs.gnugrep}/bin/grep -iq "1002"; then
      GPUINFO_AMD_GPU="$(${pkgs.pciutils}/bin/lspci -nn | ${pkgs.gnugrep}/bin/grep -Ei "VGA|3D" | ${pkgs.gnugrep}/bin/grep -m 1 "1002" | ${pkgs.gawk}/bin/awk -F'Advanced Micro Devices, Inc. ' '{gsub(/ *\[[^\]]*\]/,""); gsub(/ *\([^)]*\)/,""); print $2}')"
      AMD_ADDR=$(${pkgs.pciutils}/bin/lspci | ${pkgs.gnugrep}/bin/grep -Ei "VGA|3D" | ${pkgs.gnugrep}/bin/grep -i "''${GPUINFO_AMD_GPU}" | ${pkgs.coreutils}/bin/cut -d' ' -f1)
      {
        echo "AMD_ADDR=\"''${AMD_ADDR}\""
        echo "GPUINFO_AMD_ENABLE=1"
        echo "GPUINFO_AMD_GPU=\"''${GPUINFO_AMD_GPU}\""
      } >>"''${gpuinfo_file}"
    fi

    if ${pkgs.pciutils}/bin/lspci -nn | ${pkgs.gnugrep}/bin/grep -E "(VGA|3D)" | ${pkgs.gnugrep}/bin/grep -iq "8086"; then
      GPUINFO_INTEL_GPU="$(${pkgs.pciutils}/bin/lspci -nn | ${pkgs.gnugrep}/bin/grep -Ei "VGA|3D" | ${pkgs.gnugrep}/bin/grep -m 1 "8086" | ${pkgs.gawk}/bin/awk -F'Intel Corporation ' '{gsub(/ *\[[^\]]*\]/,""); gsub(/ *\([^)]*\)/,""); print $2}')"
      INTEL_ADDR=$(${pkgs.pciutils}/bin/lspci | ${pkgs.gnugrep}/bin/grep -Ei "VGA|3D" | ${pkgs.gnugrep}/bin/grep -i "''${GPUINFO_INTEL_GPU}" | ${pkgs.coreutils}/bin/cut -d' ' -f1)
      {
        echo "INTEL_ADDR=\"''${INTEL_ADDR}\""
        echo "GPUINFO_INTEL_ENABLE=1"
        echo "GPUINFO_INTEL_GPU=\"''${GPUINFO_INTEL_GPU}\""
      } >>"''${gpuinfo_file}"
    fi

    if ! ${pkgs.gnugrep}/bin/grep -q "GPUINFO_PRIORITY=" "''${gpuinfo_file}" && [[ -n "''${AQ_DRM_DEVICES}" ]]; then
      trap detect EXIT
    fi
  }

  toggle() {
    if [[ -n "$1" ]]; then
      NEXT_PRIORITY="GPUINFO_''${1^^}_ENABLE"
      if ! ${pkgs.gnugrep}/bin/grep -q "''${NEXT_PRIORITY}=1" "''${gpuinfo_file}"; then
        echo Error: "''${NEXT_PRIORITY}" not found in "''${gpuinfo_file}"
      fi
    else
      if ! ${pkgs.gnugrep}/bin/grep -q "GPUINFO_AVAILABLE=" "''${gpuinfo_file}"; then
        GPUINFO_AVAILABLE=$(${pkgs.gnugrep}/bin/grep "_ENABLE=1" "''${gpuinfo_file}" | ${pkgs.coreutils}/bin/cut -d '=' -f 1 | ${pkgs.coreutils}/bin/tr '\n' ' ' | ${pkgs.coreutils}/bin/tr -d '#')
        echo "" >>"''${gpuinfo_file}"
        echo "GPUINFO_AVAILABLE=\"''${GPUINFO_AVAILABLE[*]}\"" >>"''${gpuinfo_file}"
      fi

      if ! ${pkgs.gnugrep}/bin/grep -q "GPUINFO_PRIORITY=" "''${gpuinfo_file}"; then
        GPUINFO_AVAILABLE=$(${pkgs.gnugrep}/bin/grep "GPUINFO_AVAILABLE=" "''${gpuinfo_file}" | ${pkgs.coreutils}/bin/cut -d'=' -f 2)
        initGPU=$(echo "''${GPUINFO_AVAILABLE}" | ${pkgs.coreutils}/bin/cut -d ' ' -f 1)
        echo "GPUINFO_PRIORITY=''${initGPU}" >>"''${gpuinfo_file}"
      fi
      mapfile -t anchor < <(${pkgs.gnugrep}/bin/grep "_ENABLE=1" "''${gpuinfo_file}" | ${pkgs.coreutils}/bin/cut -d '=' -f 1)
      GPUINFO_PRIORITY=$(${pkgs.gnugrep}/bin/grep "GPUINFO_PRIORITY=" "''${gpuinfo_file}" | ${pkgs.coreutils}/bin/cut -d'=' -f 2)
      for index in "''${!anchor[@]}"; do
        if [[ "''${anchor[''${index}]}" = "''${GPUINFO_PRIORITY}" ]]; then
          current_index=''${index}
        fi
      done
      next_index=$(((current_index + 1) % ''${#anchor[@]}))
      NEXT_PRIORITY=''${anchor[''${next_index}]#\#}
    fi

    ${pkgs.gnused}/bin/sed -i 's/^\(GPUINFO_NVIDIA_ENABLE=1\|GPUINFO_AMD_ENABLE=1\|GPUINFO_INTEL_ENABLE=1\)/#\1/' "''${gpuinfo_file}"
    ${pkgs.gnused}/bin/sed -i "s/^#''${NEXT_PRIORITY}/''${NEXT_PRIORITY}/" "''${gpuinfo_file}"
    ${pkgs.gnused}/bin/sed -i "s/GPUINFO_PRIORITY=''${GPUINFO_PRIORITY}/GPUINFO_PRIORITY=''${NEXT_PRIORITY}/" "''${gpuinfo_file}"
  }

  map_floor() { # $1 = pairs, $2 = value -> FLOOR
    local num key value
    IFS=', ' read -r -a pairs <<<"$1"
    if [[ "''${pairs[-1]}" != *":"* ]]; then
      def_val="''${pairs[-1]}"
      unset 'pairs[''${#pairs[@]}-1]'
    fi
    for pair in "''${pairs[@]}"; do
      IFS=':' read -r key value <<<"$pair"
      num="''${2%%.*}"
      if [[ "$num" =~ ^-?[0-9]+$ && "$key" =~ ^-?[0-9]+$ ]]; then
        if ((num > key)); then
          FLOOR=$value
          return
        fi
      elif [[ -n "$num" && -n "$key" && "$num" > "$key" ]]; then
        FLOOR=$value
        return
      fi
    done
    FLOOR=""
    [ -n "$def_val" ] && FLOOR=$def_val || FLOOR=" "
  }

  get_temp_color() {
    local temp=$1
    # Пороги вручную отсортированы по убыванию: цикл не требует sort/tr
    # в подстановке (по 3 форка на каждый вызов waybar).
    local -a thresholds=(90 85 80 75 70 65 60 45 40 35 30 25 20 0)
    local -a colors=("#8b0000" "#ad1f2f" "#d22f2f" "#ff471a" "#ff6347" "#ff8c00" "#ffa500" "" "#add8e6" "#87ceeb" "#4682b4" "#4169e1" "#0000ff" "#00008b")
    local i color

    for i in "''${!thresholds[@]}"; do
      if ((temp >= thresholds[i])); then
        color="''${colors[i]}"
        if [[ -n $color ]]; then
          TEMP_COLOR="<span color='$color'><b>''${temp}°C</b></span>"
        else
          TEMP_COLOR="''${temp}°C"
        fi
        return 0
      fi
    done
    TEMP_COLOR="''${temp}°C"
  }

  generate_json() {
    if [[ ''${GPUINFO_EMOJI:-0} -ne 1 ]]; then
      temp_lv="85:, 65:, 45:☁, ❄"
    else
      temp_lv="85:🌋, 65:🔥, 45:☁️, ❄️"
    fi
    util_lv="90:, 60:󰓅, 30:󰾅, 󰾆"

    map_floor "$util_lv" "$utilization" && speedo="''${FLOOR:0:1}"
    map_floor "$temp_lv" "$temperature"
    thermo="''${FLOOR:0:1}"
    # значения temp_lv — два символа: глиф термометра + эмодзи
    emoji="''${FLOOR:1}"
    get_temp_color "''${temperature}"
    temp_color=$TEMP_COLOR

    # waybar expects {"text": ..., "tooltip": ...}: the previous version glued
    # single-quoted pseudo-keys into the tooltip, which is not valid JSON, so
    # the module was silently dropped from the bar on every tick.
    local text tooltip
    text="''${thermo} ''${temperature}°C"
    tooltip="''${emoji} ''${primary_gpu}\n''${thermo} Temperature: ''${temp_color}"

    if [[ -n "''${utilization}" ]]; then
      tooltip+="\n''${speedo} Utilization: ''${utilization}%"
    fi
    if [[ -n "''${current_clock_speed}" ]] && [[ -n "''${max_clock_speed}" ]]; then
      tooltip+="\n Clock Speed: ''${current_clock_speed}/''${max_clock_speed} MHz"
    fi
    if [[ -n "''${core_clock}" ]]; then
      tooltip+="\n Clock Speed: ''${core_clock} MHz"
    fi
    if [[ -n "''${power_usage}" ]]; then
      if [[ -n "''${power_limit}" ]]; then
        tooltip+="\n󱪉 Power Usage: ''${power_usage}/''${power_limit} W"
      else
        tooltip+="\n󱪉 Power Usage: ''${power_usage} W"
      fi
    fi
    if [[ -n "''${power_discharge}" ]] && [[ "''${power_discharge}" != "0" ]]; then
      tooltip+="\n Power Discharge: ''${power_discharge} W"
    fi
    if [[ -n "''${fan_speed}" ]]; then
      tooltip+="\n Fan Speed: ''${fan_speed} RPM"
    fi

    json_escape "''${text}"
    local escaped_text=$JSONESC
    json_escape "''${tooltip}"
    printf '{"text":"%s","tooltip":"%s"}\n' "''${escaped_text}" "''${JSONESC}"
  }

  general_query() {
    local file vfile cur volt total
    temperature=""
    fan_speed=""
    power_discharge=""

    cpu_temp && temperature=$TEMP
    cpu_fan && fan_speed=$FAN

    for file in /sys/class/power_supply/BAT*/power_now; do
      if read_num "$file"; then
        uW_to_W "$NUM"
        power_discharge=$WATT
        break
      fi
    done
    if [[ -z "$power_discharge" ]]; then
      for file in /sys/class/power_supply/BAT*/current_now; do
        vfile="''${file/current_now/voltage_now}"
        if read_num "$file" && read_num "$vfile"; then
          cur=$NUM
          volt=$(<"$vfile")
          total=$((cur * volt))
          printf -v power_discharge '%d.%d' $((total / 1000000000000)) $(( (total % 1000000000000) / 1000000000 ))
          break
        fi
      done
    fi

    get_utilization && utilization=$UTIL
    cpu_avg_freq && current_clock_speed=$FREQ
    cpu_max_freq && max_clock_speed=$MAXFREQ
  }

  intel_GPU() {
    primary_gpu="Intel ''${GPUINFO_INTEL_GPU}"
    general_query
  }

  nvidia_GPU() {
    primary_gpu="NVIDIA ''${GPUINFO_NVIDIA_GPU}"
    if [[ "''${GPUINFO_NVIDIA_GPU}" == "Linux" ]]; then
      general_query
      return
    fi
    # On a hybrid laptop the dGPU is suspended whenever nothing renders on it.
    # Waking NVML up just to print a stale 30 C costs more than the whole rest
    # of this script, so honour runtime PM by default (--tired / --no-tired).
    if ''${tired}; then
      is_suspend="$(cat /sys/bus/pci/devices/0000:"''${NVIDIA_ADDR}"/power/runtime_status 2>/dev/null)"
      if [[ ''${is_suspend} == *"suspend"* ]]; then
        printf '{"text":"󰤂", "tooltip":"%s ⏾ Suspended mode"}' "''${primary_gpu}"
        exit
      fi
    fi
    if ! command -v nvidia-smi >/dev/null 2>&1; then
      general_query
      return
    fi
    gpu_info=$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,clocks.current.graphics,clocks.max.graphics,power.draw,power.limit --format=csv,noheader,nounits)
    IFS=',' read -ra gpu_data <<<"''${gpu_info}"
    temperature="''${gpu_data[0]// /}"
    utilization="''${gpu_data[1]// /}"
    current_clock_speed="''${gpu_data[2]// /}"
    max_clock_speed="''${gpu_data[3]// /}"
    power_usage="''${gpu_data[4]// /}"
    power_limit="''${gpu_data[5]// /}"
  }

  amd_find_sysfs() { # prints the amdgpu device dir that exposes gpu_busy_percent
    local d
    for d in /sys/class/drm/card*/device; do
      if [[ -r $d/gpu_busy_percent && -d $d/hwmon ]]; then
        printf '%s' "$d"
        return 0
      fi
    done
    return 1
  }

  gpu_sclk() { # $1 = device dir -> CLOCK (MHz), current sclk from pp_dpm_sclk
    local -a raw=()
    local -a t=()
    local tok i v
    [[ -r $1/pp_dpm_sclk ]] || return 1
    read -r -a raw <"$1/pp_dpm_sclk" || return 1
    for tok in "''${raw[@]}"; do
      [[ $tok =~ ^[0-9]+:$ ]] || t+=("$tok")
    done
    for ((i = 0; i < ''${#t[@]}; i++)); do
      if [[ ''${t[i]} == '*' ]]; then
        v="''${t[i + 1]:-}"
        v="''${v%%[A-Za-z]*}"
        [[ $v =~ ^[0-9]+$ ]] || return 1
        CLOCK=$v
        return 0
      fi
    done
    return 1
  }

  amd_fast_query() { # fork-free AMD path; 1 when it cannot produce a temperature
    local dev hw
    dev="''${GPUINFO_AMD_SYSFS:-}"
    if [[ -z $dev || ! -d $dev ]]; then
      if ! dev=$(amd_find_sysfs); then
        set_state_var GPUINFO_AMD_FAST 0
        return 1
      fi
      set_state_var GPUINFO_AMD_SYSFS "$dev"
      set_state_var GPUINFO_AMD_FAST 1
    fi
    [[ "''${GPUINFO_AMD_FAST:-1}" == 1 ]] || return 1

    temperature=""
    utilization=""
    core_clock=""
    power_usage=""

    if read_num "$dev/gpu_busy_percent"; then
      utilization=$NUM
    fi
    gpu_sclk "$dev" && core_clock=$CLOCK
    for hw in "$dev"/hwmon/hwmon*; do
      [[ -d $hw ]] || continue
      if hwmon_temp "$hw" && ((TEMP > 0)); then
        temperature=$TEMP
        hwmon_power "$hw" && power_usage=$POWER
        break
      fi
    done

    [[ -n $temperature ]] || return 1

    cpu_avg_freq && current_clock_speed=$FREQ
    cpu_max_freq && max_clock_speed=$MAXFREQ
    return 0
  }

  amd_GPU() {
    primary_gpu="AMD ''${GPUINFO_AMD_GPU}"

    if amd_fast_query; then
      return 0
    fi

    if command -v amd-smi >/dev/null 2>&1 && command -v ${pkgs.jq}/bin/jq >/dev/null 2>&1; then
      local amd_output=$(amd-smi metric -t --json 2>/dev/null)
      if [ -n "$amd_output" ]; then
        temperature=$(echo "$amd_output" | ${pkgs.jq}/bin/jq -r '.gpu_0.temperature.hotspot_temp // .gpu_0.temperature.edge_temp // (to_entries[] | select(.key | startswith("gpu_")) | .value.temperature.hotspot_temp // .value.temperature.edge_temp) // empty' 2>/dev/null | ${pkgs.coreutils}/bin/head -n1)
        temperature=$(echo "$temperature" | ${pkgs.coreutils}/bin/cut -d'.' -f1 2>/dev/null)
        utilization=$(echo "$amd_output" | ${pkgs.jq}/bin/jq -r '.gpu_0.utilization.gfx_activity // (to_entries[] | select(.key | startswith("gpu_")) | .value.utilization.gfx_activity) // empty' 2>/dev/null | ${pkgs.coreutils}/bin/head -n1)
        core_clock=$(echo "$amd_output" | ${pkgs.jq}/bin/jq -r '.gpu_0.clock.gfx_clock // (to_entries[] | select(.key | startswith("gpu_")) | .value.clock.gfx_clock) // empty' 2>/dev/null | ${pkgs.coreutils}/bin/head -n1)
        power_usage=$(echo "$amd_output" | ${pkgs.jq}/bin/jq -r '.gpu_0.power.socket_power // .gpu_0.power.total_power // (to_entries[] | select(.key | startswith("gpu_")) | .value.power.socket_power // .value.power.total_power) // empty' 2>/dev/null | ${pkgs.coreutils}/bin/head -n1)
      fi
    fi

    if [ -n "$temperature" ] && [ "$temperature" != "N/A" ]; then
      for card in /sys/class/drm/card*/device; do
        if [ -L "$card/driver" ] && ${pkgs.coreutils}/bin/basename "$(${pkgs.coreutils}/bin/readlink -f "$card/driver")" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qi "amdgpu"; then
          [ -z "$utilization" ] && [ -f "''${card}/gpu_busy_percent" ] && utilization=$(cat "''${card}/gpu_busy_percent" 2>/dev/null)
          [ -z "$core_clock" ] && [ -f "''${card}/pp_dpm_sclk" ] && core_clock=$(cat "''${card}/pp_dpm_sclk" 2>/dev/null | ${pkgs.gnugrep}/bin/grep '\*' | ${pkgs.gnugrep}/bin/grep -o '[0-9]\+' | ${pkgs.coreutils}/bin/head -n1)
          break
        fi
      done
    else
      general_query
    fi
  }

  # Rebuild the state file whenever it is missing or was written by another
  # version of this script, so a layout change can never be half-applied.
  if [[ ! -f "''${gpuinfo_file}" ]] ||
    ! state_has_line "GPUINFO_VERSION=''${GPUINFO_SCRIPT_VERSION}"; then
    ${pkgs.coreutils}/bin/rm -f "''${gpuinfo_file}" "''${gpuinfo_file}.cpu"
    query
    echo -e "Initialized Variable:\n$(cat "''${gpuinfo_file}")\n\nReboot or '$0 --reset' to RESET Variables"
  fi
  source "''${gpuinfo_file}"

  # Skip NVML while the dGPU is runtime-suspended unless the user opted out.
  if ! state_has_line "tired"; then
    tired=true
  fi

  case "$1" in
  "--toggle" | "-t")
    toggle
    echo -e "Sensor: ''${NEXT_PRIORITY} GPU" | ${pkgs.gnused}/bin/sed 's/_ENABLE//g'
    exit
    ;;
  "--use" | "-u")
    toggle "$2"
    ;;
  "--reset" | "-rf")
    rm -fr "''${gpuinfo_file}"*
    query
    echo -e "Initialized Variable:\n$(cat "''${gpuinfo_file}" || true)\n\nReboot or '$0 --reset' to RESET Variables"
    exit
    ;;
  "--stat")
    case "$2" in
    "amd")
      if [[ "''${GPUINFO_AMD_ENABLE}" -eq 1 ]]; then
        echo "GPUINFO_AMD_ENABLE: ''${GPUINFO_AMD_ENABLE}"
        exit 0
      fi
      ;;
    "intel")
      if [[ "''${GPUINFO_INTEL_ENABLE}" -eq 1 ]]; then
        echo "GPUINFO_INTEL_ENABLE: ''${GPUINFO_INTEL_ENABLE}"
        exit 0
      fi
      ;;
    "nvidia")
      if [[ "''${GPUINFO_NVIDIA_ENABLE}" -eq 1 ]]; then
        echo "GPUINFO_NVIDIA_ENABLE: ''${GPUINFO_NVIDIA_ENABLE}"
        exit 0
      fi
      ;;
    *)
      echo "Error: Invalid argument for --stat. Use amd, intel, or nvidia."
      exit 1
      ;;
    esac
    echo "GPU not enabled."
    exit 1
    ;;
  *"-"*)
    GPUINFO_AVAILABLE=''${GPUINFO_AVAILABLE//GPUINFO_/}
    cat <<EOF
  Available GPU: ''${GPUINFO_AVAILABLE//_ENABLE/}
[options]
--toggle         * Toggle available GPU
--use [GPU]      * Only call the specified GPU (Useful for adding specific GPU on waybar)
--reset          *  Remove & restart all query

[flags]
--tired            * Adding this option will not query nvidia-smi if gpu is in suspend mode
--no-tired         * Always query nvidia-smi, even if gpu is in suspend mode
--startup          * Useful if you want a certain GPU to be set at startup
--emoji            * Use Emoji instead of Glyphs

* If $USER declared env = AQ_DRM_DEVICES on hyprland then use this as the primary GPU
EOF
    exit
    ;;
  esac

  GPUINFO_NVIDIA_ENABLE=''${GPUINFO_NVIDIA_ENABLE:-0} GPUINFO_INTEL_ENABLE=''${GPUINFO_INTEL_ENABLE:-0} GPUINFO_AMD_ENABLE=''${GPUINFO_AMD_ENABLE:-0}

  if [[ "''${GPUINFO_NVIDIA_ENABLE}" -eq 1 ]]; then
    nvidia_GPU
  elif [[ "''${GPUINFO_AMD_ENABLE}" -eq 1 ]]; then
    amd_GPU
  elif [[ "''${GPUINFO_INTEL_ENABLE}" -eq 1 ]]; then
    intel_GPU
  else
    primary_gpu="initialising..."
    general_query
  fi

  generate_json
''
