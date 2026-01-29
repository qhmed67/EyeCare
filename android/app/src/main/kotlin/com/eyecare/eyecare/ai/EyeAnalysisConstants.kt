package com.eyecare.eyecare.ai

object EyeAnalysisConstants {
    const val CONDITION_FATIGUE = "Eye Fatigue"
    const val CONDITION_DRY_EYE = "Dry Eye Indicators"
    const val CONDITION_INFLAMMATION = "Inflammation Indicators"

    const val PREVALENCE_FATIGUE = "Affects approximately 50-90% of computer users."
    const val PREVALENCE_DRY_EYE = "Affects between 5% and 50% of people globally."
    const val PREVALENCE_INFLAMMATION = "Commonly occurs due to allergies or environmental irritants."

    val SYMPTOMS_FATIGUE = listOf("Sore, tired eyes", "Blurry vision", "Watery or dry eyes")
    val SYMPTOMS_DRY_EYE = listOf("Stinging or burning", "Scratchy sensation", "Light sensitivity")
    val SYMPTOMS_INFLAMMATION = listOf("Redness", "Swelling", "Itching or discomfort")

    const val INSIGHTS_FATIGUE = "Prolonged screen time can lead to digital eye strain. The 20-20-20 rule is often recommended."
    const val INSIGHTS_DRY_EYE = "Can be caused by environmental factors or aging. Staying hydrated and frequent blinking may help."
    const val INSIGHTS_INFLAMMATION = "Usually a temporary response to irritants. Avoid rubbing your eyes if inflammation occurs."
}
