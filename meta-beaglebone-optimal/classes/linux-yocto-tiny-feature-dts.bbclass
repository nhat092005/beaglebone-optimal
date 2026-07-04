python __anonymous() {
    import os

    feature_keys = (d.getVar("LINUX_YOCTO_TINY_FEATURE_KEYS") or "").split()
    if not feature_keys:
        bb.fatal("LINUX_YOCTO_TINY_FEATURE_KEYS must not be empty")

    feature_root = d.getVar("LINUX_YOCTO_TINY_FEATURE_ROOT")
    if not feature_root:
        bb.fatal("LINUX_YOCTO_TINY_FEATURE_ROOT must be set")

    base_dts = d.getVar("LINUX_YOCTO_TINY_FEATURE_BASE_DTS")
    if not base_dts:
        bb.fatal("LINUX_YOCTO_TINY_FEATURE_BASE_DTS must be set")

    filespath_entries = []
    src_uri_entries = []
    enabled_dts_files = []
    seen_dts_files = set()
    for feature_key in feature_keys:
        prefix = "LINUX_YOCTO_TINY_FEATURE_%s" % feature_key
        enabled = d.getVar(prefix + "_ENABLED")
        feature_dir = d.getVar(prefix + "_DIR")
        dts_file = d.getVar(prefix + "_DTS")
        cfg_file = d.getVar(prefix + "_CFG")
        scc_file = d.getVar(prefix + "_SCC")

        if enabled not in ("0", "1"):
            bb.fatal("%s_ENABLED must be \"0\" or \"1\"" % prefix)
        if not feature_dir:
            bb.fatal("%s_DIR must be set" % prefix)
        if not dts_file:
            bb.fatal("%s_DTS must be set" % prefix)
        # CFG/SCC may legitimately be empty (feature needs no kernel config
        # fragment), but must still be declared so a missing catalog entry
        # fails loudly instead of silently acting as "no fragment".
        if cfg_file is None:
            bb.fatal("%s_CFG must be set explicitly, even if empty" % prefix)
        if scc_file is None:
            bb.fatal("%s_SCC must be set explicitly, even if empty" % prefix)

        dts_dir = os.path.join(feature_root, feature_dir, "dts")
        cfg_dir = os.path.join(feature_root, feature_dir, "cfg")
        dts_path = os.path.join(dts_dir, dts_file)

        if not os.path.exists(dts_path):
            bb.fatal("Missing declared DTS file: %s" % dts_path)

        if cfg_file:
            cfg_path = os.path.join(cfg_dir, cfg_file)
            if not os.path.exists(cfg_path):
                bb.fatal("Missing declared CFG file: %s" % cfg_path)

        if scc_file:
            scc_path = os.path.join(cfg_dir, scc_file)
            if not os.path.exists(scc_path):
                bb.fatal("Missing declared SCC file: %s" % scc_path)

        if enabled == "1":
            if dts_file in seen_dts_files:
                bb.fatal("Duplicate DTS file %s declared by feature %s" % (dts_file, feature_key))
            seen_dts_files.add(dts_file)

            filespath_entries.extend([dts_dir, cfg_dir])
            src_uri_entries.append(" file://%s" % dts_file)
            enabled_dts_files.append(dts_file)
            if cfg_file:
                src_uri_entries.append(" file://%s" % cfg_file)
            if scc_file:
                src_uri_entries.append(" file://%s" % scc_file)
                d.appendVar("KERNEL_FEATURES", " %s" % scc_file)

    if filespath_entries:
        d.prependVar("FILESEXTRAPATHS", ":".join(filespath_entries) + ":")

    d.setVar("LINUX_YOCTO_TINY_FEATURE_SRC_URI", "".join(src_uri_entries))
    d.setVar("LINUX_YOCTO_TINY_FEATURE_ENABLED_DTS_FILES", " ".join(enabled_dts_files))
}

linux_yocto_tiny_feature_dts_apply() {
	base_dts_workdir="${WORKDIR}/${LINUX_YOCTO_TINY_FEATURE_BASE_DTS}"
	dest_dts="${S}/arch/arm/boot/dts/ti/omap/${LINUX_YOCTO_TINY_FEATURE_BASE_DTS}"
	base_dts_snapshot="${T}/${LINUX_YOCTO_TINY_FEATURE_BASE_DTS}.base"
	include_file="${T}/${LINUX_YOCTO_TINY_FEATURE_BASE_DTS}.feature-includes"

	if [ -f "${base_dts_workdir}" ]; then
		base_dts="${base_dts_workdir}"
	elif [ -f "${dest_dts}" ]; then
		cp "${dest_dts}" "${base_dts_snapshot}"
		base_dts="${base_dts_snapshot}"
	else
		echo "Missing declared base DTS: ${LINUX_YOCTO_TINY_FEATURE_BASE_DTS}" >&2
		exit 1
	fi

	: > "${include_file}"

	if [ -n "${LINUX_YOCTO_TINY_FEATURE_ENABLED_DTS_FILES}" ]; then
		for feature_dtsi in ${LINUX_YOCTO_TINY_FEATURE_ENABLED_DTS_FILES}; do
			printf '#include "%s"\n' "${feature_dtsi}" >> "${include_file}"
		done

		for feature_dtsi in ${LINUX_YOCTO_TINY_FEATURE_ENABLED_DTS_FILES}; do
			install -m 0644 "${WORKDIR}/${feature_dtsi}" "${S}/arch/arm/boot/dts/ti/omap/"
		done

		install -m 0644 "${base_dts}" "${dest_dts}"
		cat "${include_file}" >> "${dest_dts}"
	else
		install -m 0644 "${base_dts}" "${dest_dts}"
	fi
}

do_configure:prepend() {
	linux_yocto_tiny_feature_dts_apply
}
