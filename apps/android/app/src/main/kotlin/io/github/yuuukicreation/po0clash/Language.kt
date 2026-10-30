package io.github.yuuukicreation.po0clash

import android.app.Activity
import android.app.LocaleManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.LocaleList

/** BCP 47 tags in the core's `language`; null follows the system. */
object Language {
    val tags = listOf(null, "zh-CN", "en", "ja", "ru")

    fun apply(activity: Activity, tag: String?) {
        if (Build.VERSION.SDK_INT >= 33) {
            activity.getSystemService(LocaleManager::class.java).applicationLocales =
                tag?.let(LocaleList::forLanguageTags) ?: LocaleList.getEmptyLocaleList()
        } else {
            activity.recreate()
        }
    }

    // Before API 33 there is no per-app locale, so each activity starts from a context in the chosen language.
    fun wrap(base: Context, tag: String?): Context {
        if (Build.VERSION.SDK_INT >= 33 || tag == null) return base
        val config = Configuration(base.resources.configuration)
        config.setLocales(LocaleList.forLanguageTags(tag))
        return base.createConfigurationContext(config)
    }
}
