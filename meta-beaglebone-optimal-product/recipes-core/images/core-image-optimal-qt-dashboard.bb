SUMMARY = "Qt dashboard product image scaffold"
DESCRIPTION = "Minimal product-side scaffold for the fullscreen Qt dashboard path."

LICENSE = "MIT"

IMAGE_LINGUAS = ""
IMAGE_NAME_SUFFIX ?= ""

IMAGE_INSTALL:append = " packagegroup-optimal-dashboard"

inherit core-image
