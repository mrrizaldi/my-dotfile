#!/bin/bash
# ====== DISPLAY NAMES (sesuai wpctl status) ======
SPEAKER_OUTPUT_DISPLAY="Headphones \["
VM70_OUTPUT_DISPLAY="VM70 Analog Stereo"
CAMERA_MIC_DISPLAY="NYK NEMESIS Analog Stereo"
VM70_MIC_DISPLAY="VM70 Analog Stereo"
LAPTOP_MIC_DISPLAY="Alder Lake PCH-P High Definition Audio Controller Digital Microphone"

# ====== NODE NAMES (untuk pw-dump) ======
HEADPHONE="alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Headphones__sink"
SPEAKER="alsa_output.usb-VM70_VM70_000003-00.analog-stereo"
HEADSET_MIC="alsa_input.usb-FEC_NYK_NEMESIS_202001010001-02.analog-stereo"
USB_MIC="alsa_input.usb-VM70_VM70_000003-00.analog-stereo"

get_sink_id() {
  wpctl status | awk '/Sinks:/,/Sources:/' | grep -E "$1" | grep -oP '\d+(?=\.)' | head -1
}

get_source_id() {
  wpctl status | awk '/Sources:/,/Filters:/' | grep -E "$1" | grep -oP '\d+(?=\.)' | head -1
}

get_default_sink_name() {
  pw-dump | jq -r '
    .[]
    | select(.type=="PipeWire:Interface:Metadata")
    | select(.info.props["metadata.name"]=="default")
    | .metadata[]
    | select(.key=="default.configured.audio.sink")
    | .value.name
  ' | head -1
}

get_default_source_name() {
  pw-dump | jq -r '
    .[]
    | select(.type=="PipeWire:Interface:Metadata")
    | select(.info.props["metadata.name"]=="default")
    | .metadata[]
    | select(.key=="default.configured.audio.source")
    | .value.name
  ' | head -1
}

get_current_sink_id() {
  # Cari yang ada tanda * (aktif) di bagian Sinks
  wpctl status | awk '/Sinks:/,/Sources:/' | grep '\*' | grep -oP '\d+(?=\.)' | head -1
}

get_current_source_id() {
  wpctl status | awk '/Sources:/,/Filters:/' | grep '\*' | grep -oP '\d+(?=\.)' | head -1
}

# ====== MAIN ======
case "$1" in
output-toggle)
  # Cycle through every sink wpctl lists (bluetooth/USB show up automatically).
  # ponytail: Intel HDMI/DP sinks skipped, HDMI port is wired to the dGPU so they're always dead
  mapfile -t SINKS < <(wpctl status | awk '/Sinks:/,/Sources:/' | grep -oP '\d+\. .*?(?=\s+\[vol)' | grep -v 'Alder Lake.*HDMI')
  CUR_ID=$(get_current_sink_id)
  NEXT=${SINKS[0]}
  for i in "${!SINKS[@]}"; do
    [ "${SINKS[i]%%.*}" = "$CUR_ID" ] && NEXT=${SINKS[(i + 1) % ${#SINKS[@]}]}
  done
  echo "Current: $CUR_ID -> $NEXT"
  wpctl set-default "${NEXT%%.*}"
  notify-send -u low -t 2000 "Audio Output" "Switched to ${NEXT#*. }"
  ;;

input-toggle)
  CUR_ID=$(get_current_source_id)
  CAM_MIC_ID=$(get_source_id "$CAMERA_MIC_DISPLAY")
  VM70_MIC_ID=$(get_source_id "$VM70_MIC_DISPLAY")
  LAPTOP_MIC_ID=$(get_source_id "$LAPTOP_MIC_DISPLAY")

  if [ "$CUR_ID" = "$VM70_MIC_ID" ]; then
    wpctl set-default "$CAM_MIC_ID"
    notify-send -u low -t 2000 "Audio Input" "Switched to ${CAMERA_MIC_DISPLAY}"
  elif [ "$CUR_ID" = "$CAM_MIC_ID" ]; then
    wpctl set-default "$LAPTOP_MIC_ID"
    notify-send -u low -t 2000 "Audio Input" "Switched to ${LAPTOP_MIC_DISPLAY}"
  else
    wpctl set-default "$VM70_MIC_ID"
    notify-send -u low -t 2000 "Audio Input" "Switched to ${VM70_MIC_DISPLAY}"
  fi
  ;;

speaker)
  ID=$(get_sink_id "$VM70_OUTPUT_DISPLAY")
  echo "Setting speaker (ID: $ID)"
  wpctl set-default "$ID"
  ;;

headphone)
  ID=$(get_sink_id "$SPEAKER_OUTPUT_DISPLAY")
  echo "Setting headphone (ID: $ID)"
  wpctl set-default "$ID"
  ;;

mic-usb)
  wpctl set-default "$(get_source_id "$VM70_MIC_DISPLAY")"
  ;;

mic-headset)
  wpctl set-default "$(get_source_id "$CAMERA_MIC_DISPLAY")"
  ;;

*)
  echo "Usage:"
  echo "  $0 output-toggle"
  echo "  $0 input-toggle"
  echo "  $0 speaker | headphone"
  echo "  $0 mic-usb | mic-headset"
  ;;
esac
