import Foundation

extension LocalizedString {
    func text(for language: AppLanguage) -> String {
        switch language {
        case .spanish: return es
        case .english: return en
        case .french: return fr
        }
    }
}

/// Curated phrase banks for the Smart Assistant's spoken/on-screen
/// feedback. A fresh random phrase is chosen per completed rep so the
/// same line doesn't repeat every time. `.notDeepEnough` and
/// `.tooFast` get separate banks instead of one shared "corrective"
/// pool: mixing them would let a range-of-motion problem get
/// announced as a speed problem, since the two conditions are
/// detected independently by `RepCounterEngine` and are not
/// interchangeable advice.
enum FeedbackPhraseBank {
    static func randomPhrase(for feedback: FormFeedback, language: AppLanguage) -> String {
        let bank = phrases(for: feedback)
        let phrase = bank.randomElement() ?? LocalizedString(es: "", en: "", fr: "")
        return phrase.text(for: language)
    }

    private static func phrases(for feedback: FormFeedback) -> [LocalizedString] {
        switch feedback {
        case .goodRep: return goodRepPhrases
        case .notDeepEnough: return notDeepEnoughPhrases
        case .tooFast: return tooFastPhrases
        case .badForm: return [] // ponytail: no copy yet, added in a later task; falls back to the empty-string phrase below
        }
    }

    static let goodRepPhrases: [LocalizedString] = [
        LocalizedString(es: "¡Bien hecho!", en: "Well done!", fr: "Bien joué !"),
        LocalizedString(es: "Excelente repetición", en: "Excellent rep", fr: "Excellente répétition"),
        LocalizedString(es: "Así se hace", en: "That's how it's done", fr: "C'est comme ça qu'il faut faire"),
        LocalizedString(es: "Perfecta ejecución", en: "Perfect execution", fr: "Exécution parfaite"),
        LocalizedString(es: "Sigue así", en: "Keep it up", fr: "Continue comme ça"),
        LocalizedString(es: "Gran repetición", en: "Great rep", fr: "Superbe répétition"),
        LocalizedString(es: "Eso es, muy bien", en: "That's it, well done", fr: "Voilà, très bien"),
        LocalizedString(es: "Forma impecable", en: "Flawless form", fr: "Forme impeccable"),
        LocalizedString(es: "Rango completo, excelente", en: "Full range, excellent", fr: "Amplitude complète, excellent"),
        LocalizedString(es: "Lo estás haciendo muy bien", en: "You're doing great", fr: "Tu t'en sors très bien"),
        LocalizedString(es: "Repetición perfecta", en: "Perfect rep", fr: "Répétition parfaite"),
        LocalizedString(es: "Buen control del movimiento", en: "Good control of the movement", fr: "Bon contrôle du mouvement"),
        LocalizedString(es: "Vas muy bien", en: "You're doing well", fr: "Tu es sur la bonne voie"),
        LocalizedString(es: "Fuerza y técnica, así", en: "Strength and technique, just like that", fr: "Force et technique, comme ça"),
        LocalizedString(es: "Esa es la técnica correcta", en: "That's the right technique", fr: "C'est la bonne technique"),
        LocalizedString(es: "Excelente esfuerzo", en: "Excellent effort", fr: "Excellent effort"),
        LocalizedString(es: "Movimiento limpio", en: "Clean movement", fr: "Mouvement propre"),
        LocalizedString(es: "Bien controlado", en: "Well controlled", fr: "Bien contrôlé"),
        LocalizedString(es: "Sigues progresando", en: "You're making progress", fr: "Tu progresses"),
        LocalizedString(es: "Esa repetición cuenta", en: "That rep counts", fr: "Cette répétition compte"),
    ]

    static let notDeepEnoughPhrases: [LocalizedString] = [
        LocalizedString(es: "No completaste el rango de movimiento", en: "You didn't complete the full range of motion", fr: "Tu n'as pas fait toute l'amplitude"),
        LocalizedString(es: "Lleva el movimiento un poco más lejos", en: "Take the movement a little further", fr: "Va un peu plus loin dans le mouvement"),
        LocalizedString(es: "Completa el movimiento en su totalidad", en: "Complete the movement in full", fr: "Effectue le mouvement en entier"),
        LocalizedString(es: "No llegaste al ángulo correcto", en: "You didn't reach the right angle", fr: "Tu n'as pas atteint le bon angle"),
        LocalizedString(es: "Completa el movimiento hasta el final", en: "Finish the movement all the way", fr: "Termine le mouvement jusqu'au bout"),
        LocalizedString(es: "Un poco más de alcance", en: "A bit more range", fr: "Un peu plus d'étendue"),
        LocalizedString(es: "Casi, pero falta rango", en: "Almost, but you need more range", fr: "Presque, mais il manque de l'amplitude"),
        LocalizedString(es: "Extiende completamente la articulación", en: "Fully extend the joint", fr: "Étends complètement l'articulation"),
        LocalizedString(es: "No te quedes a medio camino", en: "Don't stop halfway", fr: "Ne t'arrête pas à mi-chemin"),
        LocalizedString(es: "Completa más el movimiento para activar el músculo", en: "Complete more of the movement to fully engage the muscle", fr: "Termine davantage le mouvement pour bien engager le muscle"),
        LocalizedString(es: "Tu postura necesita más rango", en: "Your posture needs more range", fr: "Ta posture a besoin de plus d'amplitude"),
        LocalizedString(es: "Repite con mayor amplitud", en: "Repeat with more amplitude", fr: "Répète avec plus d'amplitude"),
        LocalizedString(es: "No se ve el rango completo", en: "I can't see the full range", fr: "Je ne vois pas toute l'amplitude"),
        LocalizedString(es: "Ajusta el ángulo del movimiento", en: "Adjust the angle of the movement", fr: "Ajuste l'angle du mouvement"),
        LocalizedString(es: "Falta llegar al punto final", en: "You need to reach the end point", fr: "Il manque d'atteindre le point final"),
        LocalizedString(es: "Lleva el movimiento más al límite", en: "Push the movement further", fr: "Pousse le mouvement plus loin"),
        LocalizedString(es: "Tu rango de movimiento es corto", en: "Your range of motion is short", fr: "Ton amplitude de mouvement est courte"),
        LocalizedString(es: "Lleva la articulación al límite", en: "Take the joint to its limit", fr: "Amène l'articulation à sa limite"),
        LocalizedString(es: "Necesitas más extensión", en: "You need more extension", fr: "Tu as besoin de plus d'extension"),
        LocalizedString(es: "Esa repetición no cuenta, falta rango", en: "That rep doesn't count, not enough range", fr: "Cette répétition ne compte pas, pas assez d'amplitude"),
    ]

    static let tooFastPhrases: [LocalizedString] = [
        LocalizedString(es: "Vas muy rápido, controla el movimiento", en: "You're going too fast, control the movement", fr: "Tu vas trop vite, contrôle le mouvement"),
        LocalizedString(es: "Más lento, controla el descenso", en: "Slow down, control the descent", fr: "Plus lentement, contrôle la descente"),
        LocalizedString(es: "Baja el ritmo", en: "Slow the pace down", fr: "Ralentis le rythme"),
        LocalizedString(es: "Controla la fase negativa", en: "Control the negative phase", fr: "Contrôle la phase négative"),
        LocalizedString(es: "Hazlo con más control", en: "Do it with more control", fr: "Fais-le avec plus de contrôle"),
        LocalizedString(es: "Menos velocidad, más técnica", en: "Less speed, more technique", fr: "Moins de vitesse, plus de technique"),
        LocalizedString(es: "Frena un poco el movimiento", en: "Slow the movement down a bit", fr: "Ralentis un peu le mouvement"),
        LocalizedString(es: "Tómate tu tiempo en cada repetición", en: "Take your time on each rep", fr: "Prends ton temps sur chaque répétition"),
    ]
}
