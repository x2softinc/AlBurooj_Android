package com.alburooj.app.data.models

import android.content.Context

object AdhanSoundPreference {
    const val STORAGE_KEY = "adhanSound"
}

/** Mapped from AdhanSoundOption.swift. [resName] is the lowercase res/raw name (null = system default). */
enum class AdhanSoundOption(val raw: String, val displayName: String, val resName: String?) {
    SystemDefault("Default", "Default", null),
    Adhan1("Adhan1", "Adhan 1", "adhan1"),
    Adhan2("Adhan2", "Adhan 2", "adhan2"),
    Adhan3("Adhan3", "Adhan 3", "adhan3"),
    Adhan4("Adhan4", "Adhan 4", "adhan4"),
    AhmadAlNafees("Ahmad_Al_Nafees", "Ahmad Al Nafees", "ahmad_al_nafees"),
    AlAqsa("AlAqsa", "Al Aqsa", "alaqsa"),
    AlHaram("Al_Haram", "Al Haram", "al_haram"),
    HafizMustafaOozcan("Hafiz_Mustafa_Oozcan", "Hafiz Mustafa Oozcan", "hafiz_mustafa_oozcan"),
    KarlJenkins("Karl_Jenkins", "Karl Jenkins", "karl_jenkins"),
    Madhina("Madhina", "Madinah", "madhina"),
    Makkah("Makkah", "Makkah", "makkah"),
    MisharyRashidAlafasy("Mishary_Rashid_Alafasy", "Mishary Rashid Alafasy", "mishary_rashid_alafasy"),
    MisharyRashidAlafasy2("Mishary_Rashid_Alafasy2", "Mishary Rashid Alafasy 2", "mishary_rashid_alafasy2"),
    MisharyRashidAlafasy3("Mishary_Rashid_Alafasy3", "Mishary Rashid Alafasy 3", "mishary_rashid_alafasy3"),
    QariAbdulKareem("Qari_Abdul_Kareem", "Qari Abdul Kareem", "qari_abdul_kareem"),
    SalahMansoorAzZahrani("Salah_Mansoor_AzZahrani", "Salah Mansoor Az Zahrani", "salah_mansoor_azzahrani"),
    SheikhJamacHareed("Sheikh_Jamac_Hareed", "Sheikh Jamac Hareed", "sheikh_jamac_hareed");

    /** android.resource:// URI string for previews / notification sound, or null for default. */
    fun uri(context: Context): String? =
        resName?.let { "android.resource://${context.packageName}/raw/$it" }

    companion object {
        fun fromRaw(raw: String?): AdhanSoundOption = entries.firstOrNull { it.raw == raw } ?: SystemDefault
    }
}
