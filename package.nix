{
  lib,
  stdenvNoCC,
  fetchurl,
  fetchFromGitHub,
  _7zz,
  python3,
  zstd,
  linux-firmware,
  # ASUS' Windows driver installer for the UX3407QA. The sha256 is what
  # matters, so any mirror serving the same bytes works. Override to use your own.
  driverExe ? fetchurl {
    name = "asus-zenbook-a14-ux3407qa-drivers.exe";
    url = "https://nc.mailliw.org/s/cFHkxSRKKb7kHQy/download";
    hash = "sha256-pNqQdUQHvQNIxQf8l5iUWcIMkL45AjyhEGgHIwatci0=";
  },
  # Subsystem ID reported by this SKU's WCN6855 (see dmesg "failed to fetch board data").
  wifiBoardNames ? [
    "bus=pci,vendor=17cb,device=1103,subsystem-vendor=14cd,subsystem-device=950a,qmi-chip-id=2,qmi-board-id=255,variant=UX3407Q"
    "bus=pci,vendor=17cb,device=1103,subsystem-vendor=14cd,subsystem-device=950a,qmi-chip-id=18,qmi-board-id=255,variant=UX3407Q"
  ],
  # QCA's tool for unpacking/repacking ath11k board-2.bin files.
  bdencoder ? fetchFromGitHub {
    owner = "qca";
    repo = "qca-swiss-army-knife";
    rev = "6df4dae3e2f5e4c2903f3cafd40996fc1b3639ce";
    hash = "sha256-FFoV58YVK7KGBw/JPFWcvGkJOONrfKCvACprYCzIKeg=";
  },
}:

let
  dir = "qcom/x1p42100/ASUSTeK/zenbook-a14";

  # Blobs from the Windows driver store, installed under ${dir}. The GPU files
  # (gen71500_*) are in linux-firmware already; qcdxkmsucpurwa.mbn is not.
  windowsFiles = [
    "adsp_dtbs.elf"
    "adspr.jsn"
    "adsps.jsn"
    "adspua.jsn"
    "battmgr.jsn"
    "cdsp_dtbs.elf"
    "cdspr.jsn"
    "qcadsp8380.mbn"
    "qccdsp8380.mbn"
    "qcdxmsuc8380.mbn"
    "qcdxkmsucpurwa.mbn"
  ];

  # Windows file -> ath11k WCN6855 hw2.1 name. linux-firmware's copies are too
  # old for this SKU.
  wifiFiles = {
    "wlanfw20.mbn" = "amss.bin";
    "regdb.bin" = "regdb.bin";
    "m3.bin" = "m3.bin";
  };

in
stdenvNoCC.mkDerivation {
  pname = "asus-zenbook-a14-firmware";
  version = "unstable";

  src = driverExe;
  dontUnpack = true;
  nativeBuildInputs = [
    _7zz
    zstd
    (python3.withPackages (_: [ ]))
  ];

  buildPhase = ''
    runHook preBuild

    mkdir extracted
    7zz x -y -bso0 -bsp0 -oextracted "$src"
    # Installers nest archives (exe -> cab/msi/zip); unpack a few levels deep.
    for pass in 1 2 3; do
      while read -r a; do
        7zz x -y -bso0 -bsp0 -o"$a.d" "$a" || true
        mv "$a" "$a.done"
      done < <(find extracted -type f \( -iname '*.zip' -o -iname '*.cab' -o -iname '*.msi' -o -iname '*.exe' \))
    done

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    root=$PWD/extracted
    find_one() {
      local found
      found=$(find "$root" -type f -iname "$1" | sort | head -n1)
      if [ -z "$found" ]; then
        echo "error: $1 not found in driver bundle" >&2
        exit 1
      fi
      echo "$found"
    }

    mkdir -p "$out/lib/firmware/${dir}"
    for f in ${lib.escapeShellArgs windowsFiles}; do
      install -Dm444 "$(find_one "$f")" "$out/lib/firmware/${dir}/$f"
    done

    # WiFi (WCN6855 hw2.1): firmware from Windows, plus a board-2.bin that
    # also contains this SKU's board data.
    wifi=$out/lib/firmware/ath11k/WCN6855/hw2.1
    mkdir -p "$wifi"
    ${lib.concatStrings (
      lib.mapAttrsToList (
        from: to: ''
          install -Dm444 "$(find_one ${lib.escapeShellArg from})" "$wifi/${to}"
        ''
      ) wifiFiles
    )}

    board=${linux-firmware}/lib/firmware/ath11k/WCN6855/hw2.0/board-2.bin
    mkdir bd && cd bd
    if [ -e "$board" ]; then cp "$board" board-2.bin; else zstd -dq "$board.zst" -o board-2.bin; fi
    python3 -I ${bdencoder}/tools/scripts/ath11k/ath11k-bdencoder -e board-2.bin > /dev/null
    rm board-2.bin
    elf=$(find_one 'bdwlan_wcn685x_2p1_nfa725a_UX3407Q.elf')
    python3 -I - "$elf" ${lib.escapeShellArgs wifiBoardNames} <<'PY'
    import json, shutil, sys
    elf, names = sys.argv[1], sys.argv[2:]
    with open("board-2.json") as f:
        d = json.load(f)
    for name in names:
        shutil.copy(elf, name + ".bin")
        d[0]["board"].append({"names": [name], "data": name + ".bin"})
    with open("board-2.json", "w") as f:
        json.dump(d, f, indent=2)
    PY
    python3 -I ${bdencoder}/tools/scripts/ath11k/ath11k-bdencoder -c board-2.json > /dev/null
    install -Dm444 board-2.bin "$wifi/board-2.bin"
    cd ..

    runHook postInstall
  '';

  meta = {
    description = "Firmware for the ASUS Zenbook A14 (UX3407QA, X1P42100) extracted from ASUS' Windows drivers: DSPs, battery and WiFi";
    license = lib.licenses.unfree;
    platforms = [ "aarch64-linux" ];
  };
}
