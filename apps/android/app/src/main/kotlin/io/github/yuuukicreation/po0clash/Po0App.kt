package io.github.yuuukicreation.po0clash

import android.app.Application
import android.content.Context

class Po0App : Application() {
    var engine: Engine? = null
        private set
    var startupError: String? = null
        private set

    override fun onCreate() {
        super.onCreate()
        try {
            engine = Engine(this)
        } catch (e: Exception) {
            startupError = e.userMessage()
        }
    }
}

val Context.engine: Engine?
    get() = (applicationContext as Po0App).engine
