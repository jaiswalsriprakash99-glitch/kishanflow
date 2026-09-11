from typing import Dict, Any

SMS_TEMPLATES: Dict[str, Dict[str, Dict[str, str]]] = {
    "en": {
        "QUEUE_DELAY_ALERT": "Hello {farmer_name}, your queue wait at {centre_name} (Ref: {booking_ref}) has changed by {wait_minutes} minutes. Recommended departure time: {rec_departure}.",
        "RECOMMENDED_DEPARTURE": "KisanFlow Alert: Time to leave! Recommended departure for {centre_name} is {rec_departure} for slot {slot_time}.",
        "BOOKING_CREATED": "Booking Confirmed! Ref: {booking_ref}, Queue #{queue_number} at {centre_name} on {slot_time}.",
        "PROCUREMENT_STATUS_CHANGED": "KisanFlow Update: Procurement status for Ref {booking_ref} is now {status}.",
        "PAYMENT_STATUS_CHANGED": "Payment Update: Payment of Rs {amount} for Ref {booking_ref} status: {status}."
    },
    "hi": {
        "QUEUE_DELAY_ALERT": "नमस्ते {farmer_name}, {centre_name} (संदर्भ: {booking_ref}) में आपकी प्रतीक्षा अवधि में {wait_minutes} मिनट का परिवर्तन हुआ है। अनुशंसित रवानगी समय: {rec_departure}।",
        "RECOMMENDED_DEPARTURE": "किसानफ़्लो अलर्ट: निकलने का समय हो गया है! {centre_name} के लिए अनुशंसित रवानगी समय {rec_departure} है।",
        "BOOKING_CREATED": "बुकिंग की पुष्टि! संदर्भ: {booking_ref}, कतार #{queue_number}, {centre_name}, समय: {slot_time}।",
        "PROCUREMENT_STATUS_CHANGED": "किसानफ़्लो अपडेट: संदर्भ {booking_ref} की खरीद स्थिति अब {status} है।",
        "PAYMENT_STATUS_CHANGED": "भुगतान अपडेट: संदर्भ {booking_ref} के लिए ₹{amount} का भुगतान स्थिति: {status}।"
    },
    "kn": {
        "QUEUE_DELAY_ALERT": "ನಮಸ್ಕಾರ {farmer_name}, {centre_name} (ಉಲ್ಲೇಖ: {booking_ref}) ನಲ್ಲಿ ನಿಮ್ಮ ಕಾಯುವ ಸಮಯ {wait_minutes} ನಿಮಿಷ ಬದಲಾಗಿದೆ. ಶಿಫಾರಸು ಮಾಡಿದ ಹೊರಡುವ ಸಮಯ: {rec_departure}.",
        "RECOMMENDED_DEPARTURE": "ಕಿಸಾನ್‌ಫ್ಲೋ ಅಲರ್ಟ್: ಹೊರಡುವ ಸಮಯವಾಗಿದೆ! {centre_name} ಗೆ ಹೊರಡುವ ಸಮಯ {rec_departure}.",
        "BOOKING_CREATED": "ಬುಕಿಂಗ್ ಖಚಿತವಾಗಿದೆ! ಉಲ್ಲೇಖ: {booking_ref}, ಸರತಿ #{queue_number}, {centre_name}.",
        "PROCUREMENT_STATUS_CHANGED": "ಸಂಗ್ರಹಣೆ ಸ್ಥಿತಿ ಉಲ್ಲೇಖ {booking_ref}: {status}.",
        "PAYMENT_STATUS_CHANGED": "ಪಾವತಿ ನವೀಕರಣ: ₹{amount} ಪಾವತಿ ಸ್ಥಿತಿ: {status}."
    },
    "mr": {
        "QUEUE_DELAY_ALERT": "नमस्कार {farmer_name}, {centre_name} (संदर्भ: {booking_ref}) मधील तुमची प्रतीक्षा वेळ {wait_minutes} मिनिटांनी बदलली आहे. निघण्याची वेळ: {rec_departure}.",
        "RECOMMENDED_DEPARTURE": "किसानफ्लो अलर्ट: निघण्याची वेळ झाली! {centre_name} साठी निघण्याची वेळ: {rec_departure}.",
        "BOOKING_CREATED": "बुकिंग निश्चित! संदर्भ: {booking_ref}, रांग #{queue_number}, {centre_name}.",
        "PROCUREMENT_STATUS_CHANGED": "खरेदी स्थिती अपडेट संदर्भ {booking_ref}: {status}.",
        "PAYMENT_STATUS_CHANGED": "पेमेंट अपडेट: ₹{amount} पेमेंट स्थिती: {status}."
    },
    "te": {
        "QUEUE_DELAY_ALERT": "నమస్కారం {farmer_name}, {centre_name} (రెఫరెన్స్: {booking_ref}) లో మీ నిరీక్షణ సమయం {wait_minutes} నిమిషాలు మారింది. బయలుదేరే సమయం: {rec_departure}.",
        "RECOMMENDED_DEPARTURE": "కిసాన్‌ఫ్లో అలర్ట్: బయలుదేరే సమయం అయింది! {centre_name} కి బయలుదేరే సమయం {rec_departure}.",
        "BOOKING_CREATED": "బుకింగ్ నిశ్చితమైంది! రెఫరెన్స్: {booking_ref}, క్యూ #{queue_number}, {centre_name}.",
        "PROCUREMENT_STATUS_CHANGED": "కొనుగోలు స్థితి రెఫరెన్స్ {booking_ref}: {status}.",
        "PAYMENT_STATUS_CHANGED": "చెల్లింపు అప్‌డేట్: ₹{amount} చెల్లింపు స్థితి: {status}."
    }
}

def render_notification_template(event_type: str, locale: str, data: Dict[str, Any]) -> str:
    lang = locale.lower() if locale and locale.lower() in SMS_TEMPLATES else "hi"
    templates_for_lang = SMS_TEMPLATES.get(lang, SMS_TEMPLATES["hi"])
    template_str = templates_for_lang.get(event_type, templates_for_lang.get("BOOKING_CREATED"))

    # Safely format template with missing key fallback
    try:
        return template_str.format(**data)
    except KeyError as ke:
        formatted = template_str
        for k, v in data.items():
            formatted = formatted.replace(f"{{{k}}}", str(v))
        return formatted
