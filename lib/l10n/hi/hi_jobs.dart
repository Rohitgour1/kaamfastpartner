/// Home dashboard, job cards, task detail, OTP / payment dialogs and booking chat.
const Map<String, String> hiJobs = {
  // Home
  'No session': 'सेशन नहीं मिला',
  'Live': 'लाइव',
  'Keep an eye out for new service requests!': 'नई रिक्वेस्ट के लिए नज़र बनाए रखें!',
  'Upcoming jobs': 'आने वाले काम',
  'No active jobs right now': 'अभी कोई चालू काम नहीं है',
  'Delivery requests': 'डिलीवरी रिक्वेस्ट',
  'Service requests': 'सर्विस रिक्वेस्ट',
  '{type} requests': '{type} रिक्वेस्ट',
  'Active': 'चालू',
  'Available': 'उपलब्ध',
  'Done today': 'आज पूरे हुए',
  'Laundry orders': 'लॉन्ड्री ऑर्डर',
  'Good Morning,': 'सुप्रभात,',
  'Good Afternoon,': 'नमस्ते,',
  'Good Evening,': 'शुभ संध्या,',
  "Today's Earnings": 'आज की कमाई',
  '{count} jobs': '{count} काम',
  'Available for Work': 'काम के लिए उपलब्ध',
  'Updating…': 'अपडेट हो रहा है…',
  'Currently accepting orders': 'अभी ऑर्डर ले रहे हैं',
  'You are offline': 'आप ऑफ़लाइन हैं',
  'Daily bonus earned!': 'आज का बोनस मिल गया!',
  'Daily Incentive Active!': 'आज का इंसेंटिव चालू है!',
  '{bonus} has been added to your wallet.': '{bonus} आपके वॉलेट में जोड़ दिए गए हैं।',
  'Complete {count} more deliveries today to earn {bonus} extra bonus.':
      'आज {count} और डिलीवरी पूरी करें और {bonus} का एक्स्ट्रा बोनस पाएं।',
  'Complete {count} more jobs today to earn {bonus} extra bonus.':
      'आज {count} और काम पूरे करें और {bonus} का एक्स्ट्रा बोनस पाएं।',

  // Job statuses & leg types from server
  'in_progress': 'चल रहा है',
  'Arrived': 'पहुँच गए',
  'picked_up': 'पिकअप हो गया',
  'Started': 'शुरू हुआ',
  'Delivered': 'डिलीवर हो गया',
  'on_the_way': 'रास्ते में',
  'Leg': 'हिस्सा',
  'Inactive': 'बंद',
  'Suspended': 'निलंबित',
  'Blocked': 'ब्लॉक',
  'not_submitted': 'जमा नहीं किया',
  'Cash': 'कैश',
  'Wallet': 'वॉलेट',

  // Task detail
  'Task detail': 'काम की जानकारी',
  'Task not found': 'काम नहीं मिला',
  'Parcel photo from customer': 'ग्राहक की पार्सल फ़ोटो',
  'Customer photo': 'ग्राहक की फ़ोटो',
  'Your leg: {leg}': 'आपका हिस्सा: {leg}',
  'Notes: {notes}': 'नोट: {notes}',
  'Locations': 'जगह',
  'Pickup': 'पिकअप',
  'Drop': 'ड्रॉप',
  'Laundry flow': 'लॉन्ड्री के चरण',
  'Waiting for partner': 'पार्टनर का इंतज़ार',
  'Completed photos': 'काम पूरा होने की फ़ोटो',
  'Add photos': 'फ़ोटो जोड़ें',
  'Add photo': 'फ़ोटो जोड़ें',
  'Add more': 'और जोड़ें',
  'Upload clear photos of completed laundry before marking complete.':
      'पूरा करने से पहले धुले कपड़ों की साफ़ फ़ोटो अपलोड करें।',
  'Show route': 'रास्ता दिखाएं',
  'View delivery search': 'डिलीवरी खोज देखें',
  'Reject': 'मना करें',
  'Accept': 'स्वीकार करें',
  'Waiting for clothes': 'कपड़ों का इंतज़ार',
  'Pickup clothes photo + OTP': 'कपड़ों की फ़ोटो + OTP से पिकअप',
  'Arrived at pickup': 'पिकअप पर पहुँच गए',
  'Pick goods & start': 'सामान लें और शुरू करें',
  'Start service': 'सर्विस शुरू करें',
  'Start task': 'काम शुरू करें',
  'Drop clothes at laundry': 'कपड़े लॉन्ड्री पर दें',
  'Complete': 'पूरा करें',

  // Searching delivery
  'Searching for delivery partner': 'डिलीवरी पार्टनर खोजा जा रहा है',
  '{count} rider nearby': 'पास में {count} राइडर',
  '{count} riders nearby': 'पास में {count} राइडर',
  'Booking Details': 'बुकिंग की जानकारी',
  'Pickup location': 'पिकअप की जगह',
  'Drop location': 'ड्रॉप की जगह',
  '{time} mins': '{time} मिनट',

  // Booking chat
  'Booking chat': 'बुकिंग चैट',
  'Refresh': 'रिफ़्रेश करें',
  'No messages yet. Say hello to start.': 'अभी कोई मैसेज नहीं। बात शुरू करने के लिए हैलो कहें।',
  'Type a message…': 'मैसेज लिखें…',

  // Task card
  'Give this OTP to the delivery partner': 'यह OTP डिलीवरी पार्टनर को दें',
  'Pickup delivery': 'पिकअप डिलीवरी',
  'Laundry service': 'लॉन्ड्री सर्विस',
  'Return delivery': 'वापसी डिलीवरी',
  'Tap for details': 'जानकारी के लिए टैप करें',
  'Fare': 'किराया',
  'Customer': 'ग्राहक',
  'From laundry': 'लॉन्ड्री से',
  'Parcel photo': 'पार्सल की फ़ोटो',
  'Assigned: {name}': 'सौंपा गया: {name}',
  'In Transit': 'रास्ते में',
  'Accept Task': 'काम स्वीकार करें',
  'Assign Rider': 'राइडर सौंपें',
  'Navigate to pickup': 'पिकअप तक जाएं',
  'Navigate to customer': 'ग्राहक तक जाएं',
  'Navigate / show route': 'रास्ता दिखाएं',
  'Navigate to laundry': 'लॉन्ड्री तक जाएं',
  'Mark laundry complete': 'लॉन्ड्री पूरी करें',
  'Upload photos & complete': 'फ़ोटो अपलोड करें और पूरा करें',
  'Collect cash & complete': 'कैश लें और पूरा करें',
  'Verify OTP & complete drop': 'OTP जाँचें और ड्रॉप पूरा करें',
  'Verify OTP & end service': 'OTP जाँचें और सर्विस खत्म करें',
  'Enter Customer OTP & Complete': 'ग्राहक का OTP डालें और पूरा करें',
  'Completed & Payout Credited': 'पूरा हुआ और पेमेंट जमा हो गया',

  // Job actions
  'Marked arrived at pickup': 'पिकअप पर पहुँचना दर्ज हो गया',
  'Upload clothes photos': 'कपड़ों की फ़ोटो अपलोड करें',
  'Pickup OTP': 'पिकअप OTP',
  'Ask the customer for the 6-digit OTP shown in their app, then collect the clothes.':
      'ग्राहक से उनके ऐप में दिखा 6 अंकों का OTP पूछें, फिर कपड़े लें।',
  'Clothes picked up. Drop them at the laundry next.': 'कपड़े ले लिए। अब इन्हें लॉन्ड्री पर दें।',
  'Upload goods photos': 'सामान की फ़ोटो अपलोड करें',
  'Start service OTP': 'सर्विस शुरू करने का OTP',
  'Ask sender/customer for the 6-digit OTP, upload goods photos, then collect payment and start.':
      'भेजने वाले/ग्राहक से 6 अंकों का OTP पूछें, सामान की फ़ोटो अपलोड करें, फिर पेमेंट लेकर शुरू करें।',
  'Ask the customer for the 6-digit OTP shown in their Kaam Fast app, then enter it to start.':
      'ग्राहक से उनके काम फास्ट ऐप में दिखा 6 अंकों का OTP पूछें, फिर शुरू करने के लिए डालें।',
  'Trip started': 'ट्रिप शुरू हो गई',
  'Service started': 'सर्विस शुरू हो गई',
  'Collect payment from sender': 'भेजने वाले से पेमेंट लें',
  'Collect full cash from the sender ({method}) before starting the trip. Confirm only after cash is received.':
      'ट्रिप शुरू करने से पहले भेजने वाले से पूरा कैश ({method}) लें। कैश मिलने के बाद ही कन्फ़र्म करें।',
  'Not yet': 'अभी नहीं',
  'Cash collected': 'कैश मिल गया',
  'Confirm sender payment': 'भेजने वाले का पेमेंट कन्फ़र्म करें',
  'Sender payment method: {method}.\nOnline / wallet payment should already be received. Confirm before starting the trip.':
      'भेजने वाले का पेमेंट तरीका: {method}।\nऑनलाइन / वॉलेट पेमेंट पहले ही मिल जाना चाहिए। ट्रिप शुरू करने से पहले कन्फ़र्म करें।',
  'Back': 'वापस',
  'Payment confirmed': 'पेमेंट कन्फ़र्म',
  'Upload proof of delivery': 'डिलीवरी का सबूत अपलोड करें',
  'Drop OTP': 'ड्रॉप OTP',
  'End service OTP': 'सर्विस खत्म करने का OTP',
  'Ask receiver for OTP, upload POD, collect cash, then complete.':
      'लेने वाले से OTP पूछें, डिलीवरी फ़ोटो अपलोड करें, कैश लें, फिर पूरा करें।',
  'Ask receiver/customer for the OTP, upload POD, then complete the trip.':
      'लेने वाले/ग्राहक से OTP पूछें, डिलीवरी फ़ोटो अपलोड करें, फिर ट्रिप पूरी करें।',
  'Ask the customer for the new 6-digit OTP. Payment / wallet settlement runs only after this OTP is verified.':
      'ग्राहक से नया 6 अंकों का OTP पूछें। यह OTP जाँचने के बाद ही पेमेंट / वॉलेट का हिसाब होगा।',
  'Ask the laundry partner for the 6-digit OTP from their app after you drop the clothes.':
      'कपड़े देने के बाद लॉन्ड्री पार्टनर से उनके ऐप का 6 अंकों का OTP पूछें।',
  'Delivery OTP': 'डिलीवरी OTP',
  'Ask the customer for the 6-digit OTP shown in their Kaam Fast app to complete return delivery.':
      'वापसी डिलीवरी पूरी करने के लिए ग्राहक से उनके काम फास्ट ऐप में दिखा 6 अंकों का OTP पूछें।',
  'Collect payment from receiver': 'लेने वाले से पेमेंट लें',
  'Collect full cash from the receiver at drop. Platform fee, tax, and commission will be deducted from your wallet after complete.':
      'ड्रॉप पर लेने वाले से पूरा कैश लें। काम पूरा होने के बाद प्लेटफ़ॉर्म फ़ीस, टैक्स और कमीशन आपके वॉलेट से कटेगा।',
  'Cash collected?': 'कैश मिल गया?',
  'Confirm you collected the full cash amount from the customer. Platform fee, tax, and commission will be deducted from your wallet.':
      'कन्फ़र्म करें कि आपने ग्राहक से पूरा कैश ले लिया है। प्लेटफ़ॉर्म फ़ीस, टैक्स और कमीशन आपके वॉलेट से कटेगा।',
  'Yes, collected': 'हाँ, मिल गया',
  'Job marked complete': 'काम पूरा हो गया',
  'Upload completed laundry photos': 'धुले कपड़ों की फ़ोटो अपलोड करें',
  'Take photo': 'फ़ोटो खींचें',
  'Choose from gallery': 'गैलरी से चुनें',
  '{count} photo uploaded': '{count} फ़ोटो अपलोड हुई',
  '{count} photos uploaded': '{count} फ़ोटो अपलोड हुईं',

  // OTP dialog
  'Enter the 6-digit OTP from the customer.': 'ग्राहक से मिला 6 अंकों का OTP डालें।',
  '6-digit OTP': '6 अंकों का OTP',
  'Ask customer to refresh OTP': 'ग्राहक से OTP रिफ़्रेश करवाएं',
  'Verify': 'जाँचें',

  // Going online
  'Account not active': 'खाता चालू नहीं है',
  'KYC required': 'KYC ज़रूरी है',
  'KYC is approved, but your account is {status}. Please contact support.':
      'KYC मंज़ूर है, लेकिन आपका खाता {status} है। कृपया सपोर्ट से संपर्क करें।',
  'KYC must be completed before you can go online.': 'ऑनलाइन जाने से पहले KYC पूरा होना चाहिए।',
  'Status: {status} · KYC: {kyc}': 'स्थिति: {status} · KYC: {kyc}',
  'Display over other apps': 'दूसरे ऐप्स के ऊपर दिखाएं',
  'Allow “Display over other apps” to show a floating bubble while receiving jobs. This lets you see your ONLINE status on top of maps and other apps.':
      'काम मिलते समय फ़्लोटिंग बबल दिखाने के लिए “दूसरे ऐप्स के ऊपर दिखाएं” की अनुमति दें। इससे आप मैप / दूसरे ऐप्स के ऊपर अपना ऑनलाइन स्टेटस देख सकते हैं।',
  'Not now': 'अभी नहीं',
  'Allow': 'अनुमति दें',
  'Allow “Display over other apps” in Settings, then try going Online again.':
      'सेटिंग्स में “दूसरे ऐप्स के ऊपर दिखाएं” की अनुमति दें, फिर दोबारा ऑनलाइन होने की कोशिश करें।',

  // Contact card & navigation
  'Phone number not available': 'फ़ोन नंबर उपलब्ध नहीं है',
  'Could not open dialer': 'डायलर नहीं खुल सका',
  'Chat unavailable for this task': 'इस काम के लिए चैट उपलब्ध नहीं है',
  'Receiver': 'लेने वाला',
  'Sender': 'भेजने वाला',
  'Call': 'कॉल करें',
  'Chat': 'चैट',
  'Customer location is missing for this job.': 'इस काम के लिए ग्राहक की लोकेशन नहीं है।',
  'Could not open Google Maps.': 'Google Maps नहीं खुल सका।',
};
