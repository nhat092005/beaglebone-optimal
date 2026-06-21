FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Common tiny-derived configurations (deterministic config, MAC setup guard)
# because beaglebone-black-optimal-qt-dashboard overrides MACHINEOVERRIDES
# to prepend "beaglebone-black-optimal-tiny", they apply to both.
SRC_URI:append:beaglebone-black-optimal-tiny = " \
	file://0002-am335x-guard-board-mac-setup-when-net-is-disabled.patch \
	file://tiny-deterministic.cfg \
"

# Machine-specific fallback DTB patches. We use an anonymous python block
# to append the correct DTB-selection patch based on the exact MACHINE name,
# preventing MACHINEOVERRIDES leakage from the product override.
python () {
    machine = d.getVar('MACHINE')
    if machine == 'beaglebone-black-optimal-tiny':
        d.appendVar('SRC_URI', ' file://0001-am335x-evm-drop-finduuid-and-use-canonical-tiny-dtb.patch')
    elif machine == 'beaglebone-black-optimal-qt-dashboard':
        d.appendVar('SRC_URI', ' file://0001-am335x-evm-drop-finduuid-and-use-canonical-qt-dashboard-dtb.patch')
}

