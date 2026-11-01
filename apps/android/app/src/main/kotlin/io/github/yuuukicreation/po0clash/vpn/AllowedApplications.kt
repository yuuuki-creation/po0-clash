package io.github.yuuukicreation.po0clash.vpn

internal fun addAvailableApplications(packages: Collection<String>, add: (String) -> Boolean): Boolean {
    var added = false
    packages.forEach { if (add(it)) added = true }
    return added
}
