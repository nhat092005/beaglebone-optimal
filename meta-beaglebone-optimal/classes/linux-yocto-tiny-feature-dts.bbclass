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

    distro_features = (d.getVar("DISTRO_FEATURES") or "").split()

    catalog = {}
    for feature_key in feature_keys:
        prefix = "LINUX_YOCTO_TINY_FEATURE_%s" % feature_key
        token = d.getVar(prefix + "_TOKEN")
        feature_dir = d.getVar(prefix + "_DIR")
        dts_file = d.getVar(prefix + "_DTS")
        cfg_file = d.getVar(prefix + "_CFG")
        scc_file = d.getVar(prefix + "_SCC")
        requires = (d.getVar(prefix + "_REQUIRES") or "").split()

        if not token:
            bb.fatal("%s_TOKEN must be set" % prefix)
        if not feature_dir:
            bb.fatal("%s_DIR must be set" % prefix)
        if not dts_file:
            bb.fatal("%s_DTS must be set" % prefix)
        # Empty CFG/SCC is valid, but missing catalog keys are not.
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

        catalog[feature_key] = {
            "token": token,
            "dts_dir": dts_dir,
            "cfg_dir": cfg_dir,
            "dts_file": dts_file,
            "cfg_file": cfg_file,
            "scc_file": scc_file,
            "requires": requires,
            "enabled": token in distro_features,
        }

    for feature_key, meta in catalog.items():
        if not meta["enabled"]:
            continue
        for required_key in meta["requires"]:
            if required_key not in catalog:
                bb.fatal("%s_REQUIRES references unknown feature key %s" % (feature_key, required_key))
            if not catalog[required_key]["enabled"]:
                bb.fatal(
                    "DISTRO_FEATURES has %s but not %s (%s requires %s)"
                    % (meta["token"], catalog[required_key]["token"], feature_key, required_key)
                )

    filespath_entries = []
    src_uri_entries = []
    enabled_dts_files = []
    seen_dts_files = set()
    for feature_key in feature_keys:
        meta = catalog[feature_key]
        if not meta["enabled"]:
            continue

        dts_file = meta["dts_file"]
        if dts_file in seen_dts_files:
            bb.fatal("Duplicate DTS file %s declared by feature %s" % (dts_file, feature_key))
        seen_dts_files.add(dts_file)

        filespath_entries.extend([meta["dts_dir"], meta["cfg_dir"]])
        src_uri_entries.append(" file://%s" % dts_file)
        enabled_dts_files.append(dts_file)
        if meta["cfg_file"]:
            src_uri_entries.append(" file://%s" % meta["cfg_file"])
        if meta["scc_file"]:
            src_uri_entries.append(" file://%s" % meta["scc_file"])
            d.appendVar("KERNEL_FEATURES", " %s" % meta["scc_file"])

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
