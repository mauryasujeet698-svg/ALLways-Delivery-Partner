import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'update_service.dart';
import 'account_security_screen.dart';
import 'delivery_service.dart';

const blue=Color(0xFF1565C0), bg=Color(0xFFF7F8FB);
const _mapboxPublicToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');
const _mapboxTilesUrl = 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}?access_token=' + _mapboxPublicToken;
const _allwaysNotificationChannel = MethodChannel('allways_notifications');
@pragma('vm:entry-point')
Future<void> _background(RemoteMessage message) async { await Firebase.initializeApp(); }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_background);
  runApp(const AllwaysDeliveryApp());
}

Future<void>? _googleSignInInitialization;

Future<void> _initializeGoogleSignIn() {
  return _googleSignInInitialization ??= Future<void>(() async {
    try {
      await GoogleSignIn.instance.initialize();
    } catch (_) {
      // Google Sign-In must not prevent the application from rendering.
    }
  });
}

class AllwaysDeliveryApp extends StatelessWidget {
  const AllwaysDeliveryApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,
    title:'ALLways Delivery Partner',
    theme:ThemeData(
      useMaterial3:true,
      colorScheme:ColorScheme.fromSeed(seedColor:blue),
      scaffoldBackgroundColor:bg,
      textTheme:GoogleFonts.poppinsTextTheme(),
      cardTheme:const CardThemeData(color:Colors.white,elevation:0,margin:EdgeInsets.zero),
    ),
    home:const AllwaysUpdateGate(repo:'mauryasujeet698-svg/ALLways-Delivery-Partner',packageChannel:'com.allways.delivery/apk_installer',assetName:'allways-delivery-partner-latest.apk',child:AuthGate()),
  );
}

class AuthGate extends StatelessWidget{
 const AuthGate({super.key});
 @override Widget build(BuildContext context)=>StreamBuilder<User?>(stream:FirebaseAuth.instance.authStateChanges(),builder:(context,s){
  if(s.data==null)return const LoginPage();
  return FutureBuilder<DocumentSnapshot<Map<String,dynamic>>>(future:FirebaseFirestore.instance.collection('deliveryPartners').doc(s.data!.uid).get(),builder:(context,a){
   if(a.hasError)return Scaffold(
    body:SafeArea(child:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
     const Icon(Icons.cloud_off_rounded,size:48,color:blue),
     const SizedBox(height:12),
     const Text('Could not load your delivery profile',textAlign:TextAlign.center,style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
     const SizedBox(height:8),
     const Text('Check your internet connection. Sign out and sign in again to retry.',textAlign:TextAlign.center),
     const SizedBox(height:16),
     FilledButton.icon(onPressed:()=>FirebaseAuth.instance.signOut(),icon:const Icon(Icons.logout),label:const Text('Back to sign in')),
    ])))),
   );
   if(!a.hasData)return const Scaffold(body:Center(child:CircularProgressIndicator()));
   if(!a.data!.exists)return PartnerRegistrationPage(user:s.data!);
   final p=a.data!.data()??{};final approval=(p['approvalStatus']??'').toString().toLowerCase();
   if(approval=='pending')return PendingApprovalPage(user:s.data!,rejected:false);
   if(approval=='rejected')return PendingApprovalPage(user:s.data!,rejected:true,reason:(p['rejectionReason']??'').toString());
   return DeliveryShell(user:s.data!);
  });
 });
}

class LoginPage extends StatefulWidget {
  final String? message;
  const LoginPage({super.key,this.message});
  @override State<LoginPage> createState()=>_LoginPageState();
}
class _LoginPageState extends State<LoginPage>{
  final email=TextEditingController(),password=TextEditingController();
  bool busy=false,obscure=true; String? error;
  Future<void> login() async {
    if(email.text.trim().isEmpty||password.text.isEmpty)return;
    setState(()=>busy=true);
    try{await FirebaseAuth.instance.signInWithEmailAndPassword(email:email.text.trim(),password:password.text);}
    on FirebaseAuthException catch(e){if(mounted)setState(()=>error=e.message??e.code);}
    catch(e){if(mounted)setState(()=>error=e.toString());}
    if(mounted)setState(()=>busy=false);
  }
  Future<void> signInWithGoogle() async {
    setState(() { busy = true; error = null; });
    try {
      await _initializeGoogleSignIn();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw Exception('Google Sign-In is not supported on this device.');
      }
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google Sign-In did not return an ID token.');
      }
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = e.message ?? e.code);
    } on GoogleSignInException catch (e) {
      if (mounted) setState(() => error = e.description ?? e.code.toString());
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
    if (mounted) setState(() => busy = false);
  }

  @override Widget build(BuildContext c)=>Scaffold(
    body:SafeArea(child:Center(child:SingleChildScrollView(
      padding:const EdgeInsets.all(24),
      child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),child:Card(
        child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const CircleAvatar(radius:29,backgroundColor:Color(0x181565C0),child:Icon(Icons.local_shipping_outlined,color:blue,size:32)),
          const SizedBox(height:18),const Text('ALLways Delivery Partner',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900)),
          const SizedBox(height:5),const Text('Deliver orders. Stay connected.'),
          if(widget.message!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(widget.message!,style:const TextStyle(color:Colors.red))),
          if(error!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(error!,style:const TextStyle(color:Colors.red))),
          const SizedBox(height:20),
          TextField(controller:email,decoration:const InputDecoration(labelText:'Email',prefixIcon:Icon(Icons.email_outlined))),
          const SizedBox(height:12),
          TextField(controller:password,obscureText:obscure,decoration:InputDecoration(labelText:'Password',prefixIcon:const Icon(Icons.lock_outline),suffixIcon:IconButton(onPressed:()=>setState(()=>obscure=!obscure),icon:Icon(obscure?Icons.visibility_outlined:Icons.visibility_off_outlined)))),
          const SizedBox(height:18),
          SizedBox(width:double.infinity,height:52,child:FilledButton(onPressed:busy?null:login,style:FilledButton.styleFrom(backgroundColor:blue),child:busy?const CircularProgressIndicator(color:Colors.white):const Text('Sign in'))),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(children: [
              Expanded(child: Divider()),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('OR')),
              Expanded(child: Divider()),
            ]),
          ),
          SizedBox(width:double.infinity,height:52,child:OutlinedButton.icon(onPressed:busy?null:signInWithGoogle,icon:const Icon(Icons.account_circle_outlined),label:const Text('Sign in with Google'))),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, height: 48, child: TextButton(
            onPressed: busy ? null : signInWithGoogle,
            child: const Text('Create New Account'),
          )),
        ])),
      )),
    ))),
  );
}


class PartnerRegistrationPage extends StatefulWidget {
  final User user;
  const PartnerRegistrationPage({super.key, required this.user});
  @override State<PartnerRegistrationPage> createState() => _PartnerRegistrationPageState();
}

class _PartnerRegistrationPageState extends State<PartnerRegistrationPage> {
  final name = TextEditingController();
  final mobile = TextEditingController();
  final address = TextEditingController();
  String vehicleType = 'bike';
  final vehicleNumber = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> submit() async {
    if (name.text.trim().isEmpty ||
        mobile.text.trim().isEmpty ||
        address.text.trim().isEmpty ||
                vehicleNumber.text.trim().isEmpty) {
      setState(() => error = 'Please complete all required fields.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final ref = FirebaseFirestore.instance.collection('deliveryPartners').doc(widget.user.uid);
      await ref.set({
        'uid': widget.user.uid,
        'role': 'delivery_partner',
        'name': name.text.trim(),
        'displayName': name.text.trim(),
        'email': widget.user.email,
        'phone': mobile.text.trim(),
        'mobileNumber': mobile.text.trim(),
        'address': address.text.trim(),
        'vehicleType': vehicleType,
        'vehicleNumber': vehicleNumber.text.trim().toUpperCase(),
        'profilePhotoUrl': widget.user.photoURL,
        'approvalStatus': 'pending',
        'status': 'pending',
        'availableForDeliveries': false,
        'availableForRides': false,
        'isOnline': false,
        'createdAt': FieldValue.serverTimestamp(),
        'submittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(TextEditingController controller, String label, {TextInputType? keyboard}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create Partner Account')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Partner registration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Complete your profile. Admin approval is required before you can go online.'),
          const SizedBox(height: 20),
          field(name, 'Full name'),
          field(mobile, 'Mobile number', keyboard: TextInputType.phone),
          field(address, 'Address'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              value: vehicleType,
              decoration: const InputDecoration(
                labelText: 'Vehicle type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'bike', child: Text('Bike')),
                DropdownMenuItem(value: 'auto', child: Text('Auto')),
                DropdownMenuItem(value: 'car', child: Text('Car')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => vehicleType = value);
              },
            ),
          ),
          field(vehicleNumber, 'Vehicle number'),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: busy ? null : submit,
              style: FilledButton.styleFrom(backgroundColor: blue),
              child: busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit for approval'),
            ),
          ),
        ],
      ),
    ),
  );
}

class PendingApprovalPage extends StatelessWidget {
  final User user;
  final bool rejected;
  final String reason;
  const PendingApprovalPage({
    super.key,
    required this.user,
    required this.rejected,
    this.reason = '',
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    rejected ? Icons.cancel_outlined : Icons.hourglass_top,
                    size: 58,
                    color: rejected ? Colors.red : blue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    rejected ? 'Registration rejected' : 'Approval pending',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rejected
                        ? (reason.isEmpty ? 'Please contact ALLways support for the next step.' : 'Reason: $reason')
                        : 'Your registration has been submitted. You can go online and accept work after Admin approval.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class DeliveryShell extends StatefulWidget {
  final User user;
  const DeliveryShell({super.key,required this.user});
  @override State<DeliveryShell> createState()=>_DeliveryShellState();
}
class _DeliveryShellState extends State<DeliveryShell>{
  int tab=0; bool online=false; Position? position; StreamSubscription<Position>? locationSub;
  StreamSubscription<QuerySnapshot<Map<String,dynamic>>>? assignmentSub;
  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<RemoteMessage>? _openedMessageSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool notificationsEnabled=true;
  String? selectedId; String? _suppressAssignmentAlertId;
  final Set<String> _knownAssignmentIds={}; final Map<String,String> _knownAssignmentStatuses={};
  bool _assignmentSnapshotReady=false, assignmentBeep=true, assignmentAudio=true;
  @override void initState(){super.initState();_load();_loadNotificationSetting();_notifications();_loadAssignmentAlertSettings();_listenForAssignments();}
  @override void dispose(){locationSub?.cancel();assignmentSub?.cancel();_messageSub?.cancel();_openedMessageSub?.cancel();_tokenRefreshSub?.cancel();super.dispose();}
  Future<void> _load() async {
    try{
      final p=await FirebaseFirestore.instance.collection('deliveryPartners').doc(widget.user.uid).get();
      final data=p.data()??{};
      online=((data['dutyStatus']??data['status']??'offline').toString().toLowerCase()=='online');
      if(online)await _startLocation();
    }catch(_){}
    if(mounted)setState((){});
  }
  Future<void> _loadNotificationSetting() async {
    final prefs=await SharedPreferences.getInstance();
    if(!mounted)return;
    setState(()=>notificationsEnabled=prefs.getBool('notifications_enabled')??true);
  }

  Future<void> _registerMessagingToken([String? suppliedToken]) async {
    final prefs=await SharedPreferences.getInstance();
    final token=suppliedToken??await FirebaseMessaging.instance.getToken();
    if(token==null||token.isEmpty)return;
    final previous=prefs.getString('fcm_token');
    if(previous!=null&&previous.isNotEmpty&&previous!=token){
      await FirebaseFirestore.instance.collection('fcmTokens').doc(widget.user.uid).collection('tokens').doc(previous).delete().catchError((_){});
    }
    await FirebaseFirestore.instance.collection('fcmTokens').doc(widget.user.uid).collection('tokens').doc(token).set({
      'uid':widget.user.uid,'token':token,'role':'delivery_partner','platform':'android','updatedAt':FieldValue.serverTimestamp(),
    },SetOptions(merge:true));
    await prefs.setString('fcm_token',token);
  }

  Future<void> _removeMessagingTokens() async {
    final snap=await FirebaseFirestore.instance.collection('fcmTokens').doc(widget.user.uid).collection('tokens').get();
    final batch=FirebaseFirestore.instance.batch();
    for(final d in snap.docs)batch.delete(d.reference);
    if(snap.docs.isNotEmpty)await batch.commit();
    try{await FirebaseMessaging.instance.deleteToken();}catch(_){}
  }

  void _handleNotificationTap(RemoteMessage message) {
    final type=(message.data['type']??'').toString().toLowerCase();
    final orderId=(message.data['orderId']??message.data['id']??'').toString();
    if(type.contains('order')||orderId.isNotEmpty){
      if(mounted)setState(()=>tab=1);
      if(orderId.isNotEmpty&&mounted)setState(()=>selectedId=orderId);
    }else if(type.contains('support')&&mounted){
      setState(()=>tab=4);
    }
  }

  Future<void> _notifications() async {
    try{
      final prefs=await SharedPreferences.getInstance();
      final enabled=prefs.getBool('notifications_enabled')??true;
      if(mounted)setState(()=>notificationsEnabled=enabled);
      if(!enabled)return;
      final settings=await FirebaseMessaging.instance.requestPermission(alert:true,badge:true,sound:true,provisional:false);
      if(settings.authorizationStatus==AuthorizationStatus.denied){
        await prefs.setBool('notifications_enabled',false);
        if(mounted)setState(()=>notificationsEnabled=false);
        return;
      }
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert:false,badge:true,sound:false);
      await FirebaseMessaging.instance.subscribeToTopic('all_users');
      await FirebaseMessaging.instance.subscribeToTopic('delivery_partners');
      await prefs.setBool('notifications_enabled',true);
      await _registerMessagingToken();
      await _messageSub?.cancel();
      _messageSub=FirebaseMessaging.onMessage.listen((RemoteMessage message){
        if(!mounted)return;
        HapticFeedback.vibrate();
        SystemSound.play(SystemSoundType.alert);
        try{_allwaysNotificationChannel.invokeMethod('showNotification',{'title':message.notification?.title??message.data['title']??'ALLways','body':message.notification?.body??message.data['body']??message.data['message']??'You have a new ALLways update.'});}catch(_){}
        final title=message.notification?.title??message.data['title']??'ALLways';
        final body=message.notification?.body??message.data['body']??'';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(body.isEmpty?title:'$title: $body'),duration:const Duration(seconds:4)));
      });
      await _openedMessageSub?.cancel();
      _openedMessageSub=FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      final initial=await FirebaseMessaging.instance.getInitialMessage();
      if(initial!=null)_handleNotificationTap(initial);
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub=FirebaseMessaging.instance.onTokenRefresh.listen((token){
        if(notificationsEnabled)_registerMessagingToken(token);
      });
    }catch(_){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Notifications could not be initialized. You can retry from Profile.')));
    }
  }

  Future<void> _setNotifications(bool value) async {
    final prefs=await SharedPreferences.getInstance();
    if(!value){
      await FirebaseMessaging.instance.unsubscribeFromTopic('all_users');
      await FirebaseMessaging.instance.unsubscribeFromTopic('delivery_partners');
      await _removeMessagingTokens();
      await prefs.setBool('notifications_enabled',false);
      if(mounted)setState(()=>notificationsEnabled=false);
      return;
    }
    final settings=await FirebaseMessaging.instance.requestPermission(alert:true,badge:true,sound:true,provisional:false);
    if(settings.authorizationStatus==AuthorizationStatus.denied){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Notification permission is blocked. Enable it in Android settings.')));
      return;
    }
    await FirebaseMessaging.instance.subscribeToTopic('all_users');
    await FirebaseMessaging.instance.subscribeToTopic('delivery_partners');
    await _registerMessagingToken();
    await prefs.setBool('notifications_enabled',true);
    if(mounted)setState(()=>notificationsEnabled=true);
  }

  Future<void> _loadAssignmentAlertSettings() async {
    final prefs=await SharedPreferences.getInstance(); if(!mounted)return;
    setState((){assignmentBeep=prefs.getBool('assignment_beep_enabled')??true;assignmentAudio=prefs.getBool('assignment_audio_enabled')??true;});
  }
  Future<void> _setAssignmentBeep(bool value) async {final p=await SharedPreferences.getInstance();await p.setBool('assignment_beep_enabled',value);if(mounted)setState(()=>assignmentBeep=value);}
  Future<void> _setAssignmentAudio(bool value) async {final p=await SharedPreferences.getInstance();await p.setBool('assignment_audio_enabled',value);if(mounted)setState(()=>assignmentAudio=value);}
  void _listenForAssignments(){
    assignmentSub=FirebaseFirestore.instance.collection('orders').where('carrierUid',isEqualTo:widget.user.uid).snapshots().listen((snap){
      if(!_assignmentSnapshotReady){for(final d in snap.docs){_knownAssignmentIds.add(d.id);_knownAssignmentStatuses[d.id]=(d.data()['status']??'').toString().toLowerCase();}_assignmentSnapshotReady=true;return;}
      for(final d in snap.docs){
        final x=d.data(); final assigned=(x['carrierUid']??x['deliveryPartnerUid']??'').toString(); final status=(x['status']??'').toString().toLowerCase();
        final active=!{'delivered','completed','cancelled','rejected','expired'}.contains(status); final previous=_knownAssignmentStatuses[d.id];
        final newlyAssigned=assigned==widget.user.uid&&active&&(previous==null||(status=='assigned'&&previous!='assigned')||!_knownAssignmentIds.contains(d.id));
        _knownAssignmentIds.add(d.id);_knownAssignmentStatuses[d.id]=status;
        if(!newlyAssigned)continue;
        if(_suppressAssignmentAlertId==d.id){_suppressAssignmentAlertId=null;continue;}
        _triggerAssignmentAlert(d.id,x);
      }
    });
  }
  Future<void> _triggerAssignmentAlert(String orderId,Map<String,dynamic> order) async {
    final orderNo=(order['id']??orderId).toString(), customer=(order['customerName']??order['name']??'customer').toString();
    final body='Order #$orderNo has been assigned to you.';
    if(assignmentBeep){HapticFeedback.heavyImpact();await SystemSound.play(SystemSoundType.alert);await Future<void>.delayed(const Duration(milliseconds:280));await SystemSound.play(SystemSoundType.alert);}
    if(assignmentAudio){try{await _allwaysNotificationChannel.invokeMethod('speakAssignment',{'text':'New delivery assigned. Order $orderNo for $customer.'});}catch(_){}}
    if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(body),duration:const Duration(seconds:5)));setState(()=>selectedId=orderId);}
  }
  Future<void> _support({String? orderId}) async {
    final subject=TextEditingController(text:orderId==null?'Delivery support':'Order #$orderId support');
    final details=TextEditingController();
    String category='Order / Delivery';
    String priority='Normal';
    try{
      final send=await showDialog<bool>(context:context,builder:(d)=>StatefulBuilder(builder:(_,setDialogState)=>AlertDialog(
        title:const Text('ALLways Support'),
        content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          DropdownButtonFormField<String>(value:category,decoration:const InputDecoration(labelText:'Issue category'),items:const[
            DropdownMenuItem(value:'Order / Delivery',child:Text('Order / Delivery')),
            DropdownMenuItem(value:'Customer / Address',child:Text('Customer / Address')),
            DropdownMenuItem(value:'Payment / Cash',child:Text('Payment / Cash')),
            DropdownMenuItem(value:'App / Technical',child:Text('App / Technical')),
            DropdownMenuItem(value:'Safety / Emergency',child:Text('Safety / Emergency')),
          ],onChanged:(v){if(v!=null)setDialogState(()=>category=v);}),
          const SizedBox(height:12),
          DropdownButtonFormField<String>(value:priority,decoration:const InputDecoration(labelText:'Priority'),items:const[
            DropdownMenuItem(value:'Normal',child:Text('Normal')),
            DropdownMenuItem(value:'High',child:Text('High')),
            DropdownMenuItem(value:'Urgent',child:Text('Urgent')),
          ],onChanged:(v){if(v!=null)setDialogState(()=>priority=v);}),
          const SizedBox(height:12),
          TextField(controller:subject,decoration:const InputDecoration(labelText:'Subject')),
          const SizedBox(height:12),
          TextField(controller:details,minLines:3,maxLines:6,decoration:const InputDecoration(labelText:'Describe the issue',hintText:'Tell ALLways operations what happened.')),
        ]))),
        actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,details.text.trim().isNotEmpty),child:const Text('Send to support'))],
      )));
      if(send!=true)return;
      await FirebaseFirestore.instance.collection('supportTickets').add({
        'requesterId':widget.user.uid,'requesterRole':'delivery_partner','uid':widget.user.uid,
        'name':widget.user.displayName??'Delivery Partner','requesterName':widget.user.displayName??widget.user.email??'Delivery Partner','email':widget.user.email??'',
        'subject':subject.text.trim().isEmpty?'Delivery support':subject.text.trim(),
        'message':details.text.trim(),'orderId':orderId??selectedId,'category':category,'priority':priority,
        'queue':'Service Support','status':'open','createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp(),
      });
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Support request sent to ALLways operations.')));
    }finally{subject.dispose();details.dispose();}
  }

  Future<bool> _locationPermission() async {
    if(!await Geolocator.isLocationServiceEnabled())return false;
    var p=await Geolocator.checkPermission();
    if(p==LocationPermission.denied)p=await Geolocator.requestPermission();
    return p!=LocationPermission.denied&&p!=LocationPermission.deniedForever;
  }
  Future<bool> _startLocation() async {
    if(!await _locationPermission())return false;
    try{
      final LocationSettings settings=Platform.isAndroid && online ? AndroidSettings(accuracy:LocationAccuracy.high,distanceFilter:10,intervalDuration:const Duration(seconds:10),foregroundNotificationConfig:const ForegroundNotificationConfig(notificationTitle:'ALLways delivery tracking',notificationText:'ALLways is sharing your location while you are online or on an active delivery.',notificationChannelName:'ALLways Delivery Tracking',enableWakeLock:true,setOngoing:true)) : const LocationSettings(accuracy:LocationAccuracy.high,distanceFilter:10);
      final first=await Geolocator.getCurrentPosition(locationSettings:settings);
      position=first;await _saveLocation(first);
      await locationSub?.cancel();
      locationSub=Geolocator.getPositionStream(locationSettings:settings).listen((p){position=p;_saveLocation(p);if(mounted)setState((){});});
      return true;
    }catch(_){return false;}
  }
  Future<void> _saveLocation(Position p) async {
    try{
      final data={'deliveryLat':p.latitude,'deliveryLng':p.longitude,'lastLat':p.latitude,'lastLng':p.longitude,'deliveryLocationUpdatedAt':FieldValue.serverTimestamp(),'lastLocationAt':FieldValue.serverTimestamp(),'isOnline':online};
      await FirebaseFirestore.instance.collection('deliveryPartners').doc(widget.user.uid).set({...data,'uid':widget.user.uid,'status':online?'online':'offline','availableForDeliveries':online,'isOnline':online},SetOptions(merge:true));
      if(selectedId!=null)await FirebaseFirestore.instance.collection('orders').doc(selectedId).set({'carrierLat':p.latitude,'carrierLng':p.longitude,'carrierLocationUpdatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
    }catch(_){}
  }
  Future<void> _setOnline(bool value) async {
    if (value) {
      final profile = await FirebaseFirestore.instance.collection('deliveryPartners').doc(widget.user.uid).get();
      final approval = (profile.data()?['approvalStatus'] ?? '').toString().toLowerCase();
      if (approval.isNotEmpty && approval != 'approved') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin approval is required before going online.')));
        return;
      }
    }
    if(value){
      if(!await _locationPermission()){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Location permission is required before going online.')));return;}
      if(!await _startLocation()){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Live location could not be started. Turn on device location and try again.')));return;}
    }else{
      await locationSub?.cancel();
      locationSub=null;
      position=null;
    }
    final data={'status':value?'online':'offline','dutyStatus':value?'online':'offline','availableForDeliveries':value,'statusUpdatedAt':FieldValue.serverTimestamp()};
    await FirebaseFirestore.instance.collection('deliveryPartners').doc(widget.user.uid).set({...data,'uid':widget.user.uid,'availableForDeliveries':value,'isOnline':value},SetOptions(merge:true));
    if(mounted)setState(()=>online=value);
  }
  Future<void> _accept(QueryDocumentSnapshot<Map<String,dynamic>> doc) async {
    try{
      await DeliveryService.acceptOrder(orderId:doc.id);
      _suppressAssignmentAlertId=doc.id;
      if(mounted){
        setState(()=>selectedId=doc.id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Order accepted.')));
      }
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));
    }
  }

  String _money(dynamic value){final n=value is num?value:num.tryParse((value??'').toString())??0;return n.toStringAsFixed(0);}
  Future<void> _status(DocumentReference<Map<String,dynamic>> ref,String value) async {
    try{
      final normalized=value.toLowerCase().trim();
      if(normalized=='delivered'){
        final pinController=TextEditingController();
        try{
          final snap=await ref.get();
          final order=snap.data()??<String,dynamic>{};
          final isCod=(order['paymentMethod']??'COD').toString().toUpperCase()=='COD';
          bool cashCollected=true;
          if(isCod){
            if(!mounted)return;
            final confirmCash=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(
              title:const Text('Collect cash'),
              content:Text('Collect ₹${_money(order['total'])} from the customer before completing this delivery.'),
              actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('Cash collected'))],
            ));
            if(confirmCash!=true)return;
            cashCollected=true;
          }
          if(!mounted)return;
          final pin=await showDialog<String>(context:context,builder:(dialogContext)=>AlertDialog(
            title:const Text('Customer confirmation'),
            content:TextField(controller:pinController,autofocus:true,keyboardType:TextInputType.number,maxLength:4,inputFormatters:[FilteringTextInputFormatter.digitsOnly],decoration:const InputDecoration(labelText:'4-digit confirmation number',hintText:'Enter customer PIN')),
            actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(dialogContext,pinController.text.trim()),child:const Text('Confirm delivery'))],
          ));
          if(pin==null||pin.length!=4)return;
          await DeliveryService.verifyDeliveryPin(orderId:ref.id,pin:pin,cashCollected:cashCollected);
          if(mounted){setState(()=>selectedId=ref.id);ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('PIN verified. Delivery completed.')));}
          return;
        }finally{pinController.dispose();}
      }
      await DeliveryService.updateStatus(orderId:ref.id,status:value);
      if(mounted){setState(()=>selectedId=ref.id);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Delivery status updated to $value.')));}
    }on FirebaseFunctionsException catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.message??'Could not update this delivery.')));
    }catch(e){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));
    }
  }

  Future<void> _call(String phone)async{final p=phone.replaceAll(RegExp(r'[^0-9+]'),'');if(p.isNotEmpty)await launchUrl(Uri(scheme:'tel',path:p),mode:LaunchMode.externalApplication);}
  Future<void> _sos()async{await FirebaseFirestore.instance.collection('sosAlerts').add({'uid':widget.user.uid,'role':'delivery_partner','createdAt':FieldValue.serverTimestamp(),'status':'open'});if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('SOS alert sent to ALLways operations.')));}
  @override Widget build(BuildContext context){
    final pages=[
      DeliveryHome(online:online,position:position,onOnline:_setOnline,onAccept:_accept,onSelect:(id)=>setState(()=>selectedId=id),widgetUserUid:widget.user.uid),
      DeliveryOrders(user:widget.user,onStatus:_status,onSelect:(id)=>setState(()=>selectedId=id),onCall:_call,onSupport:_support),
      DeliveryMap(user:widget.user,selectedId:selectedId,position:position),
      Earnings(user:widget.user),
      Profile(user:widget.user,onSos:_sos,assignmentBeep:assignmentBeep,assignmentAudio:assignmentAudio,onAssignmentBeep:_setAssignmentBeep,onAssignmentAudio:_setAssignmentAudio,notificationsEnabled:notificationsEnabled,onNotifications:_setNotifications,onSupport:_support),
    ];
    return Scaffold(
      body:SafeArea(child:IndexedStack(index:tab,children:pages)),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const[
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),
        NavigationDestination(icon:Icon(Icons.local_shipping_outlined),selectedIcon:Icon(Icons.local_shipping),label:'Deliveries'),
        NavigationDestination(icon:Icon(Icons.map_outlined),selectedIcon:Icon(Icons.map),label:'Live Map'),
        NavigationDestination(icon:Icon(Icons.currency_rupee_outlined),selectedIcon:Icon(Icons.currency_rupee),label:'Earnings'),
        NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Profile'),
      ]),
    );
  }
}

class DeliveryHome extends StatelessWidget{
  final bool online;final Position? position;final Future<void> Function(bool) onOnline;final Future<void> Function(QueryDocumentSnapshot<Map<String,dynamic>>) onAccept;final void Function(String) onSelect;final String widgetUserUid;
  const DeliveryHome({super.key,required this.online,required this.position,required this.onOnline,required this.onAccept,required this.onSelect,required this.widgetUserUid});
  double n(dynamic v)=>v is num?v.toDouble():double.tryParse((v??'').toString())??0;
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.fromLTRB(16,18,16,28),children:[
    Row(children:[const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('ALLways Delivery',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),SizedBox(height:3),Text('Nearby orders and live delivery work',style:TextStyle(color:Colors.grey))])),Switch(value:online,onChanged:onOnline)]),
    const SizedBox(height:8),
    Card(elevation:0,child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[CircleAvatar(backgroundColor:blue.withOpacity(.10),child:Icon(online?Icons.play_arrow:Icons.pause,color:blue)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(online?'You are ready for deliveries':'You are offline',style:const TextStyle(fontWeight:FontWeight.w900)),Text(online?'Next action: accept an order, then Pick Up → Deliver.':'Next action: go online when you are ready to receive work.',style:const TextStyle(color:Colors.grey,fontSize:12))]))]))),
    const SizedBox(height:12),
    Card(color:blue.withOpacity(.07),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[CircleAvatar(radius:26,backgroundColor:blue.withOpacity(.12),child:Icon(online?Icons.wifi_tethering:Icons.wifi_off,color:blue)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(online?'You are online':'You are offline',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text(online?'New delivery work can be assigned.':'Turn on duty status to receive nearby work.',style:const TextStyle(color:Colors.grey))]))]))),
    const SizedBox(height:16),
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream:FirebaseFirestore.instance.collection('orders').snapshots(),
      builder:(context,s){
        if(!s.hasData)return const Card(child:Padding(padding:EdgeInsets.all(24),child:Center(child:CircularProgressIndicator())));
        if(!online||position==null)return Card(child:Padding(padding:const EdgeInsets.all(24),child:Center(child:Text(online?'Waiting for live location...':'Go online to view nearby delivery requests.'))));
        final list=<QueryDocumentSnapshot<Map<String,dynamic>>>[];
        for(final d in s.data!.docs){
          final x=d.data();final assigned=(x['carrierUid']??x['deliveryPartnerUid']??'').toString();final status=(x['status']??'').toString().toLowerCase();
          final assignedToMe=assigned==widgetUserUid;
          final unassigned=assigned.isEmpty;
          final pendingAuto=assignedToMe && status=='pending_acceptance';
          if(!unassigned && !pendingAuto)continue;
          final lat=n(x['customerLatitude']??x['pickupLatitude']??x['pickupLat']);final lng=n(x['customerLongitude']??x['pickupLongitude']??x['pickupLng']);
          if((assigned.isNotEmpty&&!pendingAuto)||!['new order','searching','ready','pending','pending_acceptance','assigned'].contains(status)||status=='delivered'||status=='cancelled'||status=='completed'||status=='rejected'||status=='expired'||lat==0||lng==0)continue;
          if(Geolocator.distanceBetween(position!.latitude,position!.longitude,lat,lng)<=7000)list.add(d);
        }
        if(list.isEmpty)return const Card(child:Padding(padding:EdgeInsets.all(24),child:Center(child:Text('No nearby delivery requests within 7 km.'))));
        return Column(children:list.map((d){
          final x=d.data();final km=Geolocator.distanceBetween(position!.latitude,position!.longitude,n(x['customerLatitude']??x['pickupLatitude']??x['pickupLat']),n(x['customerLongitude']??x['pickupLongitude']??x['pickupLng']))/1000;
          return Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[const CircleAvatar(backgroundColor:Color(0x1A1565C0),child:Icon(Icons.inventory_2_outlined,color:blue)),const SizedBox(width:10),Expanded(child:Text('#'+(x['id']??d.id).toString(),style:const TextStyle(fontWeight:FontWeight.w900))),Text(km.toStringAsFixed(1)+' km',style:const TextStyle(color:blue,fontWeight:FontWeight.w800))]),
            const SizedBox(height:8),Text((x['name']??x['customerName']??'Customer').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),Text((x['address']??'Pickup address unavailable').toString(),maxLines:2,overflow:TextOverflow.ellipsis),const SizedBox(height:8),Text('₹'+n(x['total']).toStringAsFixed(0),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
            const SizedBox(height:10),Row(children:[Expanded(child:OutlinedButton(onPressed:()=>onSelect(d.id),child:const Text('View map'))),const SizedBox(width:8),Expanded(child:FilledButton(onPressed:()=>onAccept(d),style:FilledButton.styleFrom(backgroundColor:blue),child:const Text('Accept')))]),
          ])));
        }).toList());
      },
    ),
  ]);
}

class _OrderItemsSheet extends StatelessWidget{
  final Map<String,dynamic> order;
  const _OrderItemsSheet({required this.order});
  num n(dynamic v)=>v is num?v:num.tryParse((v??'').toString())??0;
  @override Widget build(BuildContext context){
    final raw=order['items'];
    final items=raw is List
        ? raw.whereType<Map>().map((x)=>Map<String,dynamic>.from(x)).toList()
        : <Map<String,dynamic>>[];
    return SafeArea(
      child:Padding(
        padding:const EdgeInsets.fromLTRB(20,8,20,24),
        child:Column(
          mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,
          children:[
            const Text('Order items',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),
            const SizedBox(height:10),
            if(items.isEmpty)
              const Text('No item details were saved with this order.'),
            for(final x in items)
              ListTile(
                dense:true,
                leading:const Icon(Icons.inventory_2_outlined),
                title:Text(
                  (x['name']??x['title']??'Item').toString(),
                  style:const TextStyle(fontWeight:FontWeight.w700),
                ),
                subtitle:Text('Qty: '+(x['qty']??x['quantity']??1).toString()),
                trailing:Text('₹'+n(x['price']).toStringAsFixed(0)),
              ),
            const Divider(),
            Align(
              alignment:Alignment.centerRight,
              child:Text(
                'Total: ₹'+n(order['total']).toStringAsFixed(0),
                style:const TextStyle(fontWeight:FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeliveryOrders extends StatelessWidget{
  final User user; final Future<void> Function(DocumentReference<Map<String,dynamic>>,String) onStatus; final void Function(String) onSelect; final Future<void> Function(String) onCall; final Future<void> Function({String? orderId}) onSupport;
  const DeliveryOrders({super.key,required this.user,required this.onStatus,required this.onSelect,required this.onCall,required this.onSupport});
  num n(dynamic v)=>v is num?v:num.tryParse((v??'').toString())??0;
  DateTime stamp(Map<String,dynamic> x){
    for(final k in const ['assignedAt','deliveredAt','completedAt','updatedAt','createdAt']){
      final v=x[k]; if(v is Timestamp)return v.toDate(); if(v is DateTime)return v;
      if(v is num){final q=v.toInt();return DateTime.fromMillisecondsSinceEpoch(q<100000000000?q*1000:q);}
      if(v!=null){final p=DateTime.tryParse(v.toString());if(p!=null)return p;}
    } return DateTime.fromMillisecondsSinceEpoch(0);
  }
  Widget card(BuildContext c,QueryDocumentSnapshot<Map<String,dynamic>> d,bool done){
    final x=d.data(), status=(x['status']??(done?'Delivered':'Assigned')).toString(), phone=(x['phone']??x['customerPhone']??'').toString();
    return Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text('#'+(x['id']??d.id).toString(),style:const TextStyle(fontWeight:FontWeight.w900))),Text('₹'+n(x['total']).toStringAsFixed(0),style:const TextStyle(fontWeight:FontWeight.w900))]),
      const SizedBox(height:7),Text((x['name']??x['customerName']??'Customer').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),Text((x['address']??'Address unavailable').toString(),maxLines:2,overflow:TextOverflow.ellipsis),
      const SizedBox(height:8),Text(status,style:const TextStyle(color:blue,fontWeight:FontWeight.w800)),
      const SizedBox(height:10),Row(children:[
        Expanded(child:OutlinedButton(onPressed:()=>showModalBottomSheet(context:c,showDragHandle:true,builder:(_)=>_OrderItemsSheet(order:x)),child:const Text('View items'))),
        if(!done)...[const SizedBox(width:8),Expanded(child:OutlinedButton(onPressed:()=>onSelect(d.id),child:const Text('Live map')))],
        if(!done&&phone.isNotEmpty)IconButton(tooltip:'Call customer',onPressed:()=>onCall(phone),icon:const Icon(Icons.call_outlined)),
      ]),
      if(!done&&['assigned','pending_acceptance'].contains(status.toLowerCase()))SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>onStatus(d.reference,'Picked Up'),style:FilledButton.styleFrom(backgroundColor:blue),child:const Text('Confirm pickup'))),
      if(!done&&status.toLowerCase()=='picked up')SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>onStatus(d.reference,'Out for delivery'),style:FilledButton.styleFrom(backgroundColor:blue),child:const Text('Start delivery'))),
      if(!done&&status.toLowerCase()=='out for delivery')SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>onStatus(d.reference,'Arrived'),style:FilledButton.styleFrom(backgroundColor:blue),child:const Text('Arrived at customer'))),
      if(!done&&status.toLowerCase()=='arrived')SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>onStatus(d.reference,'Delivered'),style:FilledButton.styleFrom(backgroundColor:Colors.green),child:const Text('Complete with PIN'))),
      if(!done)Padding(padding:const EdgeInsets.only(top:8),child:OutlinedButton.icon(onPressed:()=>onSupport(orderId:d.id),icon:const Icon(Icons.report_problem_outlined),label:const Text('Report an issue'))),
    ])));
  }
  @override Widget build(BuildContext c)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
    stream:FirebaseFirestore.instance.collection('orders').where('carrierUid',isEqualTo:user.uid).snapshots(),
    builder:(context,s){
      if(s.hasError)return Center(child:Text('Could not load deliveries: '+s.error.toString())); if(!s.hasData)return const Center(child:CircularProgressIndicator());
      final active=<QueryDocumentSnapshot<Map<String,dynamic>>>[], delivered=<QueryDocumentSnapshot<Map<String,dynamic>>>[];
      for(final d in s.data!.docs){final st=(d.data()['status']??'').toString().toLowerCase(); if({'cancelled','rejected','expired'}.contains(st))continue; if({'delivered','completed'}.contains(st))delivered.add(d);else active.add(d);}
      active.sort((a,b)=>stamp(b.data()).compareTo(stamp(a.data())));delivered.sort((a,b)=>stamp(b.data()).compareTo(stamp(a.data())));
      final recent=delivered.take(3).toList();
      if(active.isEmpty&&recent.isEmpty)return const Center(child:Text('No assigned deliveries yet.'));
      return ListView(padding:const EdgeInsets.fromLTRB(16,18,16,28),children:[
        const Text('My Deliveries',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:12),
        if(active.isNotEmpty)...[const Text('Assigned deliveries',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800)),const SizedBox(height:8),...active.map((d)=>card(c,d,false))]
        else const Padding(padding:EdgeInsets.only(bottom:12),child:Text('No active assigned deliveries.')),
        if(recent.isNotEmpty)...[const SizedBox(height:8),const Text('Last 3 delivered',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800)),const SizedBox(height:4),const Text('Only your three most recent delivered orders are shown here.',style:TextStyle(color:Colors.grey,fontSize:12)),const SizedBox(height:8),...recent.map((d)=>card(c,d,true))],
      ]);
    },
  );
}

class DeliveryMap extends StatefulWidget{
  final User user;final String? selectedId;final Position? position;
  const DeliveryMap({super.key,required this.user,required this.selectedId,required this.position});
  @override State<DeliveryMap> createState()=>_DeliveryMapState();
}

class _DeliveryMapState extends State<DeliveryMap>{
  final MapController _mapController=MapController();
  bool _ready=false; DateTime? _lastMove;
  double n(dynamic v)=>v is num?v.toDouble():double.tryParse((v??'').toString())??0;

  void _focus(LatLng me,LatLng? destination){
    if(!_ready)return;
    final now=DateTime.now();
    if(_lastMove!=null&&now.difference(_lastMove!)<const Duration(milliseconds:900))return;
    if(destination!=null){
      final meters=Geolocator.distanceBetween(me.latitude,me.longitude,destination.latitude,destination.longitude);
      final zoom=meters<=30?18.8:meters<=100?18.0:meters<=300?17.0:meters<=1000?15.7:14.5;
      _mapController.move(LatLng((me.latitude+destination.latitude)/2,(me.longitude+destination.longitude)/2),zoom);
    }else{
      _mapController.move(me,16);
    }
    _lastMove=now;
  }

  @override Widget build(BuildContext c)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
    stream:FirebaseFirestore.instance.collection('orders').where('carrierUid',isEqualTo:widget.user.uid).snapshots(),
    builder:(context,s){
      QueryDocumentSnapshot<Map<String,dynamic>>? chosen;
      for(final d in s.data?.docs??const <QueryDocumentSnapshot<Map<String,dynamic>>>[])if(widget.selectedId==d.id)chosen=d;
      chosen??=(s.data?.docs.isNotEmpty==true?s.data!.docs.first:null);
      final x=chosen?.data();
      final lat=n(x?['customerLat']??x?['customerLatitude']??x?['destinationLatitude']);
      final lng=n(x?['customerLng']??x?['customerLongitude']??x?['destinationLongitude']);
      final me=widget.position==null?null:LatLng(widget.position!.latitude,widget.position!.longitude);
      final destination=(lat!=0&&lng!=0)?LatLng(lat,lng):null;
      if(me!=null)WidgetsBinding.instance.addPostFrameCallback((_)=>_focus(me,destination));
      final distance=me!=null&&destination!=null?Geolocator.distanceBetween(me.latitude,me.longitude,destination.latitude,destination.longitude):null;
      final markers=<Marker>[
        if(me!=null)Marker(point:me,width:58,height:58,child:const Pin(color:blue,icon:Icons.local_shipping)),
        if(destination!=null)Marker(point:destination,width:58,height:58,child:const Pin(color:Colors.red,icon:Icons.location_on)),
      ];
      return Stack(children:[
        FlutterMap(
          mapController:_mapController,
          options:MapOptions(
            initialCenter:me??const LatLng(25.4358,81.8463),
            initialZoom:15,
            onMapReady:(){_ready=true;if(me!=null)_focus(me,destination);},
          ),
          children:[
            TileLayer(urlTemplate: _mapboxTilesUrl,maxZoom:19,userAgentPackageName:'com.allways.delivery'),
            MarkerLayer(markers:markers),
          ],
        ),
        Positioned(top:14,left:14,right:14,child:SafeArea(bottom:false,child:Card(child:Padding(padding:const EdgeInsets.all(13),child:Row(children:[
          const Icon(Icons.navigation,color:blue),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(chosen==null?'Live delivery map':'Tracking order #'+chosen.id,style:const TextStyle(fontWeight:FontWeight.w800)),
            if(distance!=null)Text(distance<1000?'Customer live • '+distance.round().toString()+' m away':'Customer live • '+(distance/1000).toStringAsFixed(1)+' km away',style:const TextStyle(color:Colors.grey,fontSize:12)),
          ])),
          IconButton(
            tooltip:'Navigate to customer',
            onPressed:destination==null?null:()async{
              final url=Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&travelmode=driving');
              try{await launchUrl(url,mode:LaunchMode.externalApplication);}catch(_){}
            },
            icon:const Icon(Icons.directions_outlined,color:blue),
          ),
        ]))))),
        Positioned(
          right:12,
          bottom:110,
          child:SafeArea(
            child:Column(mainAxisSize:MainAxisSize.min,children:[
              FloatingActionButton.small(heroTag:'delivery-zoom-in',onPressed:_ready?()=>_mapController.move(_mapController.camera.center,_mapController.camera.zoom+1):null,child:const Icon(Icons.add)),
              const SizedBox(height:8),
              FloatingActionButton.small(heroTag:'delivery-zoom-out',onPressed:_ready?()=>_mapController.move(_mapController.camera.center,_mapController.camera.zoom-1):null,child:const Icon(Icons.remove)),
              const SizedBox(height:8),
              FloatingActionButton.small(heroTag:'delivery-center',onPressed:!_ready?null:()=>_focus(widget.position==null?const LatLng(25.4358,81.8463):LatLng(widget.position!.latitude,widget.position!.longitude),destination),child:const Icon(Icons.my_location)),
            ]),
          ),
        ),
      ]);
    },
  );
}

class Pin extends StatelessWidget{final Color color;final IconData icon;const Pin({super.key,required this.color,required this.icon});@override Widget build(BuildContext c)=>Container(decoration:BoxDecoration(color:color,shape:BoxShape.circle,border:Border.all(color:Colors.white,width:4),boxShadow:const[BoxShadow(color:Colors.black26,blurRadius:6)]),child:Icon(icon,color:Colors.white,size:25));}

class Earnings extends StatelessWidget{
  final User user;const Earnings({super.key,required this.user});
  num n(dynamic v)=>v is num?v:num.tryParse((v??'').toString())??0;
  DateTime stamp(Map<String,dynamic> x){
    final v=x['deliveredAt']??x['completedAt']??x['updatedAt']??x['createdAt'];
    if(v is Timestamp)return v.toDate();
    if(v is DateTime)return v;
    if(v is num)return DateTime.fromMillisecondsSinceEpoch(v.toInt()<100000000000?v.toInt()*1000:v.toInt());
    return DateTime.tryParse((v??'').toString())??DateTime.fromMillisecondsSinceEpoch(0);
  }
  @override Widget build(BuildContext c)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
    stream:FirebaseFirestore.instance.collection('orders').where('carrierUid',isEqualTo:user.uid).snapshots(),
    builder:(context,s){
      final done=<QueryDocumentSnapshot<Map<String,dynamic>>>[];
      num all=0,today=0,week=0;
      final now=DateTime.now();final dayStart=DateTime(now.year,now.month,now.day);final weekStart=dayStart.subtract(Duration(days:now.weekday-1));
      for(final d in s.data?.docs??const <QueryDocumentSnapshot<Map<String,dynamic>>>[]){
        final x=d.data();final st=(x['status']??'').toString().toLowerCase();
        if(st!='delivered'&&st!='completed')continue;
        final earning=n(x['partnerEarning']??x['deliveryEarning']);
        all+=earning;final at=stamp(x);if(at.isAfter(dayStart))today+=earning;if(at.isAfter(weekStart))week+=earning;done.add(d);
      }
      done.sort((a,b)=>stamp(b.data()).compareTo(stamp(a.data())));
      return ListView(padding:const EdgeInsets.fromLTRB(16,18,16,28),children:[
        const Text('Earnings',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:12),
        Row(children:[
          Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Today',style:TextStyle(color:Colors.grey)),const SizedBox(height:5),Text('₹'+today.toStringAsFixed(0),style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900))])))),
          const SizedBox(width:10),
          Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('This week',style:TextStyle(color:Colors.grey)),const SizedBox(height:5),Text('₹'+week.toStringAsFixed(0),style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900))])))),
        ]),
        const SizedBox(height:10),
        Card(child:ListTile(leading:const Icon(Icons.account_balance_wallet_outlined,color:blue),title:Text('₹'+all.toStringAsFixed(0),style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),subtitle:Text(done.length.toString()+' completed deliveries • earnings supplied by ALLways operations'))),
        const SizedBox(height:14),
        const Text('Recent completed deliveries',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800)),const SizedBox(height:8),
        if(!s.hasData)const Center(child:CircularProgressIndicator()),
        if(s.hasData&&done.isEmpty)const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('Completed delivery earnings will appear here.'))),
        if(s.hasData)
          ...done.take(10).map((d){
            final x=d.data();
            return Card(
              margin:const EdgeInsets.only(bottom:8),
              child:ListTile(
                leading:const Icon(Icons.check_circle_outline,color:Colors.green),
                title:Text('#'+(x['id']??d.id).toString(),style:const TextStyle(fontWeight:FontWeight.w800)),
                subtitle:Text((x['customerName']??x['name']??'Customer').toString()),
                trailing:Text('₹'+n(x['partnerEarning']??x['deliveryEarning']).toStringAsFixed(0),style:const TextStyle(fontWeight:FontWeight.w900)),
              ),
            );
          })
      ]);
    },
  );
}

Future<void> _showPartnerDocuments(BuildContext context, User user) async {
  showDialog(context:context,builder:(d)=>FutureBuilder<DocumentSnapshot<Map<String,dynamic>>>(
    future:FirebaseFirestore.instance.collection('deliveryPartners').doc(user.uid).get(),
    builder:(context,s){
      if(!s.hasData)return const AlertDialog(content:SizedBox(height:70,child:Center(child:CircularProgressIndicator())));
      final x=s.data!.data()??{};
      return AlertDialog(
        title:const Text('Documents & verification'),
        content:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Approval: '+((x['approvalStatus']??'unknown').toString()),style:const TextStyle(fontWeight:FontWeight.w800)),
          const SizedBox(height:10),
          Text('Vehicle type: '+((x['vehicleType']??'—').toString())),
          Text('Vehicle number: '+((x['vehicleNumber']??'—').toString())),
          Text('Phone: '+((x['phone']??x['mobileNumber']??'—').toString())),
          const SizedBox(height:12),
          const Text('Keep these details accurate. Additional KYC/document checks are controlled by ALLways operations.',style:TextStyle(color:Colors.grey)),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Close'))],
      );
    },
  ));
}

Future<void> _chooseAllwaysLanguage(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final current = prefs.getString('app_language') ?? 'English';
  if (!context.mounted) return;
  final selected = await showDialog<String>(
    context: context,
    builder: (d) => SimpleDialog(
      title: const Text('Language'),
      children: [
        RadioListTile<String>(value: 'English', groupValue: current, title: const Text('English'), onChanged: (v) => Navigator.pop(d, v)),
        RadioListTile<String>(value: 'Hindi', groupValue: current, title: const Text('हिन्दी'), onChanged: (v) => Navigator.pop(d, v)),
      ],
    ),
  );
  if (selected != null) {
    await prefs.setString('app_language', selected);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Language set to $selected.')),
    );
  }
}

class Profile extends StatelessWidget{
  final User user; final Future<void> Function() onSos; final bool assignmentBeep, assignmentAudio, notificationsEnabled;
  final Future<void> Function(bool) onAssignmentBeep, onAssignmentAudio, onNotifications; final Future<void> Function({String? orderId}) onSupport;
  const Profile({super.key,required this.user,required this.onSos,required this.assignmentBeep,required this.assignmentAudio,required this.notificationsEnabled,required this.onAssignmentBeep,required this.onAssignmentAudio,required this.onNotifications,required this.onSupport});
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.fromLTRB(16,18,16,28),children:[
    const Text('Profile & Safety',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:12),
    Card(child:ListTile(leading:const Icon(Icons.person_outline,color:blue),title:Text(user.displayName??'Delivery Partner'),subtitle:Text(user.email??''))),
    Card(child:ListTile(leading:const Icon(Icons.language,color:blue),title:const Text('Language'),subtitle:const Text('English / हिन्दी'),trailing:const Icon(Icons.chevron_right),onTap:()=>_chooseAllwaysLanguage(c))),
    Card(child:SwitchListTile(secondary:const Icon(Icons.notifications_active_outlined,color:blue),title:const Text('Enable Notifications'),subtitle:const Text('Receive ALLways alerts and new delivery assignments.'),value:notificationsEnabled,onChanged:onNotifications)),
    Card(child:SwitchListTile(secondary:const Icon(Icons.notifications_none_outlined,color:blue),title:const Text('Assignment beep'),subtitle:const Text('Play a beep when a new delivery is assigned.'),value:assignmentBeep,onChanged:onAssignmentBeep)),
    Card(child:SwitchListTile(secondary:const Icon(Icons.record_voice_over_outlined,color:blue),title:const Text('Assignment audio'),subtitle:const Text('Read the new assignment aloud.'),value:assignmentAudio,onChanged:onAssignmentAudio)),
    Card(child:ListTile(leading:const Icon(Icons.description_outlined),title:const Text('Documents'),subtitle:const Text('View your current vehicle and verification details.'),trailing:const Icon(Icons.chevron_right),onTap:()=>_showPartnerDocuments(c,user))),
    Card(child:ListTile(leading:const Icon(Icons.help_outline,color:blue),title:const Text('Help & Support'),subtitle:const Text('Send a delivery issue to ALLways operations.'),trailing:const Icon(Icons.chevron_right),onTap:onSupport)),
    Card(child:ListTile(leading:const Icon(Icons.sos,color:Colors.red),title:const Text('SOS / Emergency'),subtitle:const Text('Send an alert to ALLways operations.'),onTap:onSos)),
    Card(child:ListTile(leading:const Icon(Icons.security,color:blue),title:const Text('Account & Security'),subtitle:const Text('Updates, privacy policy and account deletion.'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>AccountSecurityScreen(user:user,role:'delivery_partner',profileCollection:'deliveryPartners',repository:'mauryasujeet698-svg/ALLways-Delivery-Partner',accent:blue))))),
    Card(child:ListTile(leading:const Icon(Icons.logout),title:const Text('Sign out'),onTap:()=>FirebaseAuth.instance.signOut())),
  ]);
}