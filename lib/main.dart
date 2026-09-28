import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'account_theme.dart';
import 'package:url_launcher/url_launcher.dart';

const blue=Color(0xFF1565C0), bg=Color(0xFFF7F8FB);
const cloudinaryCloudName='busdtvia';
const cloudinaryUploadPreset='allways_preset';

@pragma('vm:entry-point')
Future<void> _background(RemoteMessage message) async { await Firebase.initializeApp(); }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await GoogleSignIn.instance.initialize();
  await appThemeController.load();
  FirebaseMessaging.onBackgroundMessage(_background);
  runApp(const AllwaysDeliveryApp());
}

class AllwaysDeliveryApp extends StatelessWidget {
  const AllwaysDeliveryApp({super.key});
  @override Widget build(BuildContext context)=>ValueListenableBuilder<ThemeMode>(
    valueListenable:appThemeController,
    builder:(context,mode,_)=>MaterialApp(
    debugShowCheckedModeBanner:false,
    title:'ALLways Delivery Partner',
    theme:ThemeData(
      useMaterial3:true,
      colorScheme:ColorScheme.fromSeed(seedColor:blue),
      scaffoldBackgroundColor:bg,
      textTheme:GoogleFonts.poppinsTextTheme(),
      cardTheme:const CardThemeData(color:Colors.white,elevation:0,margin:EdgeInsets.zero),
    ),
    themeMode:mode,
    darkTheme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:blue,brightness:Brightness.dark),textTheme:GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme)),
    home:const AuthGate(),
  ),
  );
}

class AuthGate extends StatelessWidget{
 const AuthGate({super.key});
 @override Widget build(BuildContext context)=>StreamBuilder<User?>(stream:FirebaseAuth.instance.authStateChanges(),builder:(context,s){
  if(s.data==null)return const LoginPage();
  return FutureBuilder<DocumentSnapshot<Map<String,dynamic>>>(future:FirebaseFirestore.instance.collection('deliveryPartners').doc(s.data!.uid).get(),builder:(context,a){
   if(!a.hasData)return const Scaffold(body:Center(child:CircularProgressIndicator()));
   if(!a.data!.exists)return PartnerRegistrationPage(user:s.data!);
   final p=a.data!.data()??{};final approval=(p['approvalStatus']??'').toString().toLowerCase();
   if(approval=='pending')return PendingApprovalPage(user:s.data!,rejected:false);
   if(approval=='rejected')return PendingApprovalPage(user:s.data!,rejected:true,reason:(p['rejectionReason']??'').toString());
   if(approval=='suspended')return PendingApprovalPage(user:s.data!,rejected:true,reason:(p['suspensionReason']??'Account suspended by Admin.').toString());
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
  final vehicleType = TextEditingController();
  final vehicleNumber = TextEditingController();
  XFile? profilePhoto;
  XFile? vehiclePhoto;
  bool busy = false;
  String? error;

  Future<XFile?> _pickPhoto() => ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 60, maxWidth: 800);

  Future<String> _uploadPhoto(XFile file, String folder) async {
    final request = http.MultipartRequest('POST', Uri.parse('https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload'));
    request.fields['upload_preset'] = cloudinaryUploadPreset;
    request.fields['folder'] = folder;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('Photo upload failed: $body');
    final match = RegExp(r'"secure_url"\s*:\s*"([^"]+)"').firstMatch(body);
    if (match == null) throw Exception('Cloudinary did not return a secure URL.');
    return match.group(1)!;
  }

  Future<void> _chooseProfilePhoto() async {
    try { final f=await _pickPhoto(); if(f!=null && mounted)setState(()=>profilePhoto=f); }
    catch(e){ if(mounted)setState(()=>error=e.toString()); }
  }

  Future<void> _chooseVehiclePhoto() async {
    try { final f=await _pickPhoto(); if(f!=null && mounted)setState(()=>vehiclePhoto=f); }
    catch(e){ if(mounted)setState(()=>error=e.toString()); }
  }

  Future<void> submit() async {
    if (name.text.trim().isEmpty ||
        mobile.text.trim().isEmpty ||
        address.text.trim().isEmpty ||
        vehicleType.text.trim().isEmpty ||
        vehicleNumber.text.trim().isEmpty ||
        profilePhoto == null ||
        vehiclePhoto == null) {
      setState(() => error = 'Please complete all required fields and photos.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final profileUrl = await _uploadPhoto(profilePhoto!, 'allways/profiles/delivery_partners');
      final vehicleUrl = await _uploadPhoto(vehiclePhoto!, 'allways/vehicles/delivery_partners');
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
        'vehicleType': vehicleType.text.trim().toLowerCase(),
        'vehicleNumber': vehicleNumber.text.trim().toUpperCase(),
        'profilePhotoUrl': profileUrl,
        'vehiclePhotoUrl': vehicleUrl,
        'approvalStatus': 'pending',
        'status': 'pending',
        'availableForDeliveries': false,
        'availableForRides': false,
        'isOnline': false,
        'createdAt': FieldValue.serverTimestamp(),
        'submittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PendingApprovalPage(user: widget.user, rejected: false)));
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
          field(vehicleType, 'Vehicle type'),
          field(vehicleNumber, 'Vehicle number'),
          OutlinedButton.icon(
            onPressed: busy ? null : _chooseProfilePhoto,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(profilePhoto == null ? 'Upload profile photo' : 'Profile photo selected'),
          ),
          if (profilePhoto != null) Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(profilePhoto!.path), height: 140, width: double.infinity, fit: BoxFit.cover)),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : _chooseVehiclePhoto,
            icon: const Icon(Icons.directions_car_outlined),
            label: Text(vehiclePhoto == null ? 'Upload vehicle photo' : 'Vehicle photo selected'),
          ),
          if (vehiclePhoto != null) Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(vehiclePhoto!.path), height: 140, width: double.infinity, fit: BoxFit.cover)),
          ),
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
                        : 'Request submitted. Waiting for approval.',
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
  int tab=0; bool online=false; Position? position; StreamSubscription<Position>? locationSub; String? selectedId;
  @override void initState(){super.initState();_load();_notifications();}
  @override void dispose(){locationSub?.cancel();super.dispose();}
  Future<void> _load() async {
    try{
      final c=await FirebaseFirestore.instance.collection('deliveryPartners').doc(widget.user.uid).get();
      online=((c.data()?['dutyStatus']??c.data()?['status']??'offline').toString().toLowerCase()=='online');
      if(online)await _startLocation();
    }catch(_){}
    if(mounted)setState((){});
  }
  Future<void> _notifications() async {
    try{
      final p=await SharedPreferences.getInstance();
      if(p.getBool('notifications_enabled')==false)return;
      final s=await FirebaseMessaging.instance.requestPermission(alert:true,badge:true,sound:true);
      if(s.authorizationStatus==AuthorizationStatus.denied)return;
      await FirebaseMessaging.instance.subscribeToTopic('all_users');
      await FirebaseMessaging.instance.subscribeToTopic('delivery_partners');
      await p.setBool('notifications_enabled', true);
      Future<void> saveToken(String? t) async {
        if(t==null||t.isEmpty)return;
        await FirebaseFirestore.instance.collection('fcmTokens').doc(widget.user.uid).collection('tokens').doc(t).set({'uid':widget.user.uid,'token':t,'role':'delivery_partner','updatedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));
      }
      await saveToken(await FirebaseMessaging.instance.getToken());
      FirebaseMessaging.instance.onTokenRefresh.listen(saveToken);
    }catch(_){}
  }
  Future<bool> _locationPermission() async {
    if(!await Geolocator.isLocationServiceEnabled())return false;
    var p=await Geolocator.checkPermission();
    if(p==LocationPermission.denied)p=await Geolocator.requestPermission();
    return p!=LocationPermission.denied&&p!=LocationPermission.deniedForever;
  }
  Future<void> _startLocation() async {
    if(!await _locationPermission())return;
    try{
      const settings=LocationSettings(accuracy:LocationAccuracy.high,distanceFilter:10);
      final first=await Geolocator.getCurrentPosition(locationSettings:settings);
      position=first;await _saveLocation(first);
      await locationSub?.cancel();
      locationSub=Geolocator.getPositionStream(locationSettings:settings).listen((p){position=p;_saveLocation(p);if(mounted)setState((){});});
    }catch(_){}
  }
  Future<void> _saveLocation(Position p) async {
    try{
      final data={'deliveryLat':p.latitude,'deliveryLng':p.longitude,'deliveryLocationUpdatedAt':FieldValue.serverTimestamp()};
      await FirebaseFirestore.instance.collection('deliveryPartners').doc(widget.user.uid).set({...data,'uid':widget.user.uid,'status':online?'online':'offline'},SetOptions(merge:true));
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
    if(value&&!await _locationPermission()){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Location permission is required before going online.')));return;}
    if(value)await _startLocation();else await locationSub?.cancel();
    final data={'status':value?'online':'offline','dutyStatus':value?'online':'offline','availableForDeliveries':value,'statusUpdatedAt':FieldValue.serverTimestamp()};
    await FirebaseFirestore.instance.collection('deliveryPartners').doc(widget.user.uid).set({...data,'uid':widget.user.uid},SetOptions(merge:true));
    if(mounted)setState(()=>online=value);
  }
  Future<void> _accept(QueryDocumentSnapshot<Map<String,dynamic>> doc) async {
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final latest = await tx.get(doc.reference);
        final x = latest.data() ?? {};
        final assigned = (x['carrierUid'] ?? '').toString();
        if (assigned != widget.user.uid) throw Exception('This delivery is not assigned to you.');
        if ((x['status'] ?? '').toString().toLowerCase() != 'pending_acceptance') {
          throw Exception('This delivery is no longer awaiting acceptance.');
        }
        final profile = await tx.get(
          FirebaseFirestore.instance.collection('deliveryPartners').doc(widget.user.uid),
        );
        final p = profile.data() ?? {};
        tx.update(doc.reference, {
          'carrierUid': widget.user.uid,
          'assignedPartnerId': widget.user.uid,
          'carrierName': p['name'] ?? p['displayName'] ?? 'ALLways Delivery Partner',
          'carrierPhone': p['phone'] ?? p['mobileNumber'] ?? widget.user.phoneNumber ?? '',
          'carrierAccepted': true,
          'assignmentRejected': false,
          'status': 'Assigned',
          'statusNote': 'Accepted by delivery partner',
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        tx.set(
          profile.reference,
          {
            'pendingOrderId': null,
            'currentOrderId': doc.id,
            'availableForDeliveries': false,
            'dutyStatus': 'on_delivery',
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
      if (mounted) {
        setState(() => selectedId = doc.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order accepted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _reject(QueryDocumentSnapshot<Map<String,dynamic>> doc) async {
    try {
      final x = doc.data();
      if ((x['carrierUid'] ?? '').toString() != widget.user.uid) {
        throw Exception('This delivery is not assigned to you.');
      }
      await doc.reference.update({
        'carrierUid': null,
        'assignedPartnerId': null,
        'carrierAccepted': false,
        'assignmentRejected': true,
        'status': 'unassigned',
        'statusNote': 'Rejected by delivery partner',
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery offer rejected. Admin can reassign it.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reject: '+e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _status(DocumentReference ref,String value) async {try{await ref.update({'status':value,'updatedAt':FieldValue.serverTimestamp(),'statusNote':'Updated by ALLways Delivery Partner'});}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Update failed: '+e.toString())));}}
  Future<void> _call(String phone)async{final p=phone.replaceAll(RegExp(r'[^0-9+]'),'');if(p.isNotEmpty)await launchUrl(Uri(scheme:'tel',path:p),mode:LaunchMode.externalApplication);}
  Future<void> _sos()async{await FirebaseFirestore.instance.collection('sosAlerts').add({'uid':widget.user.uid,'role':'delivery_partner','createdAt':FieldValue.serverTimestamp(),'status':'open'});if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('SOS alert sent to ALLways operations.')));}
  @override Widget build(BuildContext context){
    final pages=[
      DeliveryHome(userUid:widget.user.uid,online:online,position:position,onOnline:_setOnline,onAccept:_accept,onReject:_reject,onSelect:(id)=>setState(()=>selectedId=id)),
      DeliveryOrders(user:widget.user,onStatus:_status,onSelect:(id)=>setState(()=>selectedId=id),onCall:_call),
      DeliveryMap(user:widget.user,selectedId:selectedId,position:position),
      Earnings(user:widget.user),
      Profile(user:widget.user,onSos:_sos),
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
  final bool online;
  final Position? position;
  final String userUid;
  final Future<void> Function(bool) onOnline;
  final Future<void> Function(QueryDocumentSnapshot<Map<String,dynamic>>) onAccept;
  final Future<void> Function(QueryDocumentSnapshot<Map<String,dynamic>>) onReject;
  final void Function(String) onSelect;

  const DeliveryHome({
    super.key,
    required this.online,
    required this.position,
    required this.userUid,
    required this.onOnline,
    required this.onAccept,
    required this.onReject,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext c)=>ListView(
    padding:const EdgeInsets.fromLTRB(16,18,16,28),
    children:[
      Row(children:[
        const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('ALLways Delivery',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
          SizedBox(height:3),
          Text('Assigned delivery work and live delivery status',style:TextStyle(color:Colors.grey)),
        ])),
        Switch(value:online,onChanged:onOnline),
      ]),
      const SizedBox(height:12),
      Card(
        color:blue.withOpacity(.07),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),
        child:Padding(
          padding:const EdgeInsets.all(16),
          child:Row(children:[
            CircleAvatar(radius:26,backgroundColor:blue.withOpacity(.12),child:Icon(online?Icons.wifi_tethering:Icons.wifi_off,color:blue)),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(online?'You are online':'You are offline',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
              const Text('Orders are assigned by ALLways Admin.',style:TextStyle(color:Colors.grey)),
            ])),
          ]),
        ),
      ),
      const SizedBox(height:16),
      StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream:FirebaseFirestore.instance.collection('orders').where('carrierUid',isEqualTo:userUid).snapshots(),
        builder:(context,s){
          if(s.hasError)return Card(child:Padding(padding:const EdgeInsets.all(20),child:Text('Could not load assigned offers: '+s.error.toString())));
          if(!s.hasData)return const Card(child:Padding(padding:EdgeInsets.all(24),child:Center(child:CircularProgressIndicator())));
          final offers=s.data!.docs.where((d)=>(d.data()['status']??'').toString().toLowerCase()=='pending_acceptance').toList();
          if(offers.isEmpty)return const Card(child:Padding(padding:EdgeInsets.all(24),child:Center(child:Text('No pending delivery assignments.'))));
          return Column(children:offers.map((d){
            final x=d.data();
            return Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('#'+(x['id']??d.id).toString(),style:const TextStyle(fontWeight:FontWeight.w900)),
              const SizedBox(height:7),
              Text((x['name']??x['customerName']??'Customer').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),
              Text((x['address']??'Address unavailable').toString(),maxLines:2,overflow:TextOverflow.ellipsis),
              const SizedBox(height:8),
              Text('₹'+(x['total']??0).toString(),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
              const SizedBox(height:10),
              Row(children:[
                Expanded(child:OutlinedButton(onPressed:()=>onReject(d),child:const Text('Reject'))),
                const SizedBox(width:8),
                Expanded(child:OutlinedButton(onPressed:()=>onSelect(d.id),child:const Text('View map'))),
                const SizedBox(width:8),
                Expanded(child:FilledButton(onPressed:()=>onAccept(d),style:FilledButton.styleFrom(backgroundColor:blue),child:const Text('Accept'))),
              ]),
            ])));
          }).toList());
        },
      ),
    ],
  );
}

class DeliveryOrders extends StatelessWidget{
  final User user;final Future<void> Function(DocumentReference,String) onStatus;final void Function(String) onSelect;final Future<void> Function(String) onCall;
  const DeliveryOrders({super.key,required this.user,required this.onStatus,required this.onSelect,required this.onCall});
  num n(dynamic v)=>v is num?v:num.tryParse((v??'').toString())??0;
  @override Widget build(BuildContext c)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
    stream:FirebaseFirestore.instance.collection('orders').where('carrierUid',isEqualTo:user.uid).snapshots(),
    builder:(context,s){
      if(s.hasError)return Center(child:Text('Could not load deliveries: '+s.error.toString()));
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      final docs=s.data!.docs;
      if(docs.isEmpty)return const Center(child:Text('No assigned deliveries yet.'));
      return ListView(padding:const EdgeInsets.fromLTRB(16,18,16,28),children:[
        const Text('My Deliveries',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:12),
        ...docs.map((d){final x=d.data();final status=(x['status']??'Assigned').toString();final phone=(x['phone']??x['customerPhone']??'').toString();
          return Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Expanded(child:Text('#'+(x['id']??d.id).toString(),style:const TextStyle(fontWeight:FontWeight.w900))),Text('₹'+n(x['total']).toStringAsFixed(0),style:const TextStyle(fontWeight:FontWeight.w900))]),
            const SizedBox(height:7),Text((x['name']??x['customerName']??'Customer').toString(),style:const TextStyle(fontWeight:FontWeight.w700)),Text((x['address']??'Address unavailable').toString(),maxLines:2,overflow:TextOverflow.ellipsis),const SizedBox(height:8),Text(status,style:const TextStyle(color:blue,fontWeight:FontWeight.w800)),
            const SizedBox(height:10),Row(children:[Expanded(child:OutlinedButton(onPressed:()=>onSelect(d.id),child:const Text('Live map'))),if(phone.isNotEmpty)IconButton(onPressed:()=>onCall(phone),icon:const Icon(Icons.call_outlined))]),
            if(status=='Assigned'||status=='pending_acceptance')SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>onStatus(d.reference,'Out for delivery'),style:FilledButton.styleFrom(backgroundColor:blue),child:const Text('Start delivery'))),
            if(status=='Out for delivery')SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>onStatus(d.reference,'Delivered'),style:FilledButton.styleFrom(backgroundColor:Colors.green),child:const Text('Mark delivered'))),
          ])));
        }),
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
  final MapController _map=MapController();
  List<LatLng> route=[];List<Map<String,dynamic>> steps=[];double? routeDistance,routeDuration;String? loadedId;bool loading=false;
  double n(dynamic v)=>v is num?v.toDouble():double.tryParse((v??'').toString())??0;
  LatLng? point(dynamic a,dynamic b){final x=n(a),y=n(b);return x==0||y==0?null:LatLng(x,y);}
  @override void didUpdateWidget(covariant DeliveryMap old){super.didUpdateWidget(old);if(widget.selectedId!=old.selectedId)load();}
  @override void initState(){super.initState();WidgetsBinding.instance.addPostFrameCallback((_){load();});}
  Future<void> load()async{
    final id=widget.selectedId;if(id==null||id.isEmpty)return;
    try{
      final snap=await FirebaseFirestore.instance.collection('orders').doc(id).get();final x=snap.data()??{};
      final target=point(x['customerLatitude']??x['destinationLatitude']??x['latitude'],x['customerLongitude']??x['destinationLongitude']??x['longitude']);
      final start=widget.position==null?null:LatLng(widget.position!.latitude,widget.position!.longitude);
      if(start==null||target==null)return;loading=true;if(mounted)setState((){});
      final url=Uri.parse('https://router.project-osrm.org/route/v1/driving/\${start.longitude},\${start.latitude};\${target.longitude},\${target.latitude}?overview=full&geometries=geojson&steps=true');
      final res=await http.get(url);if(res.statusCode!=200)return;
      final body=jsonDecode(res.body),routes=body['routes'];if(routes is! List||routes.isEmpty)return;final r=routes.first;
      final coords=r['geometry']?['coordinates'];
      final pts=coords is List?coords.whereType<List>().where((q)=>q.length>=2).map((q)=>LatLng((q[1] as num).toDouble(),(q[0] as num).toDouble())).toList():<LatLng>[];
      final ss=<Map<String,dynamic>>[];final legs=r['legs'];
      if(legs is List)for(final leg in legs){final raw=leg['steps'];if(raw is! List)continue;for(final step in raw){final m=step['maneuver'] is Map?Map<String,dynamic>.from(step['maneuver']):<String,dynamic>{};ss.add({'instruction':(m['type']??'continue').toString()=='arrive'?'You have arrived':(m['modifier']??'Continue straight').toString().replaceAll('_',' '),'road':(step['name']??'').toString(),'distance':step['distance'] is num?(step['distance'] as num).toDouble():0});}}
      if(mounted)setState((){route=pts;steps=ss;routeDistance=r['distance'] is num?(r['distance'] as num).toDouble():null;routeDuration=r['duration'] is num?(r['duration'] as num).toDouble():null;loadedId=id;});
    }catch(_){}finally{loading=false;if(mounted)setState((){});}
  }
  Widget pin(Color c,IconData i)=>Container(decoration:BoxDecoration(color:c,shape:BoxShape.circle,border:Border.all(color:Colors.white,width:4),boxShadow:const[BoxShadow(color:Colors.black26,blurRadius:6)]),child:Icon(i,color:Colors.white,size:25));
  @override Widget build(BuildContext c)=>StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream:widget.selectedId==null?null:FirebaseFirestore.instance.collection('orders').doc(widget.selectedId).snapshots(),builder:(context,s){
    final x=s.data?.data()??{};final target=point(x['customerLatitude']??x['destinationLatitude']??x['latitude'],x['customerLongitude']??x['destinationLongitude']??x['longitude']);final me=widget.position==null?null:LatLng(widget.position!.latitude,widget.position!.longitude);
    final center=me??target??const LatLng(25.4358,81.8463);
    final markers=<Marker>[if(me!=null)Marker(point:me,width:56,height:56,child:pin(blue,Icons.local_shipping)),if(target!=null)Marker(point:target,width:56,height:56,child:pin(Colors.red,Icons.person))];
    final d=me!=null&&target!=null?Geolocator.distanceBetween(me.latitude,me.longitude,target.latitude,target.longitude):null;
    return Stack(children:[FlutterMap(mapController:_map,options:MapOptions(initialCenter:center,initialZoom:15),children:[TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',maxZoom:19,userAgentPackageName:'com.allways.delivery'),if(route.isNotEmpty)PolylineLayer(polylines:[Polyline(points:route,color:blue,strokeWidth:6)]),MarkerLayer(markers:markers)]),
      Positioned(top:12,left:12,right:12,child:SafeArea(bottom:false,child:Card(color:const Color(0xFFFDECEF),child:Padding(padding:const EdgeInsets.all(13),child:Row(children:[const Icon(Icons.circle,color:Colors.green,size:12),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Live delivery navigation',style:TextStyle(fontWeight:FontWeight.w900)),Text(d==null?'Waiting for live location':(d<1000?d.round().toString()+' m from customer':(d/1000).toStringAsFixed(1)+' km from customer'),style:const TextStyle(color:Colors.grey,fontSize:12))]))]))))),
      if(steps.isNotEmpty)Positioned(top:86,left:12,right:12,child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[Container(width:48,height:48,alignment:Alignment.center,decoration:BoxDecoration(color:blue,borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.navigation,color:Colors.white,size:27)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Next turn',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),Text('Follow the highlighted route',style:TextStyle(color:Colors.grey))]))])))),
      Positioned(left:12,right:12,bottom:18,child:SafeArea(top:false,child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Customer delivery',style:TextStyle(fontWeight:FontWeight.w900,fontSize:16)),if(routeDistance!=null)Text((routeDistance!<1000?routeDistance!.round().toString()+' m':(routeDistance!/1000).toStringAsFixed(1)+' km')+' route • ETA '+((routeDuration??0)/60).ceil().toString()+' min',style:const TextStyle(color:Colors.grey))])),if(widget.selectedId!=null)IconButton(onPressed:load,icon:const Icon(Icons.refresh))]))))),
    ]);
  });
}
class Pin extends StatelessWidget{final Color color;final IconData icon;const Pin({super.key,required this.color,required this.icon});@override Widget build(BuildContext c)=>Container(decoration:BoxDecoration(color:color,shape:BoxShape.circle,border:Border.all(color:Colors.white,width:4),boxShadow:const[BoxShadow(color:Colors.black26,blurRadius:6)]),child:Icon(icon,color:Colors.white,size:25));}

class Earnings extends StatelessWidget{
  final User user;const Earnings({super.key,required this.user});
  num n(dynamic v)=>v is num?v:num.tryParse((v??'').toString())??0;
  @override Widget build(BuildContext c)=>StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
    stream:FirebaseFirestore.instance.collection('orders').where('carrierUid',isEqualTo:user.uid).snapshots(),
    builder:(context,s){num value=0;int done=0;for(final d in s.data?.docs??const <QueryDocumentSnapshot<Map<String,dynamic>>>[]){final x=d.data();final st=(x['status']??'').toString().toLowerCase();if(st=='delivered'||st=='completed'){done++;value+=n(x['partnerEarning']??x['deliveryEarning']??x['deliveryFee']);}}
      return ListView(padding:const EdgeInsets.fromLTRB(16,18,16,28),children:[const Text('Earnings',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:12),Row(children:[Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.currency_rupee,color:blue),const SizedBox(height:8),Text('₹'+value.toStringAsFixed(0),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const Text('Completed earnings',style:TextStyle(color:Colors.grey))])))),const SizedBox(width:10),Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.check_circle_outline,color:Colors.green),const SizedBox(height:8),Text(done.toString(),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const Text('Completed',style:TextStyle(color:Colors.grey))]))))])]);
    },
  );
}

class Profile extends StatelessWidget{
  final User user;final Future<void> Function() onSos;const Profile({super.key,required this.user,required this.onSos});
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.fromLTRB(16,18,16,28),children:[
    const Text('Profile & Safety',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:12),
    Card(child:ListTile(leading:const Icon(Icons.person_outline,color:blue),title:Text(user.displayName??'Delivery Partner'),subtitle:Text(user.email??''))),
    Card(child:ListTile(leading:const Icon(Icons.description_outlined),title:const Text('Documents'),subtitle:const Text('Keep vehicle and verification details current.'),onTap:()=>showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('Documents'),content:const Text('Your submitted profile and vehicle documents are stored with your ALLways partner account. Contact ALLways operations if a document needs correction.'),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Close'))])))),
    Card(child:ListTile(leading:const Icon(Icons.help_outline),title:const Text('Help & Support'),subtitle:const Text('Contact ALLways operations for delivery issues.'),onTap:()=>showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('Help & Support'),content:const Text('For delivery issues, contact ALLways operations with the order ID and a short description of the problem.'),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Close'))])))),
    Card(child:ListTile(leading:const Icon(Icons.sos,color:Colors.red),title:const Text('SOS / Emergency'),subtitle:const Text('Send an alert to ALLways operations.'),onTap:onSos)),
    Card(child:ListTile(leading:const Icon(Icons.palette_outlined,color:blue),title:const Text('Change Theme'),subtitle:const Text('Light, dark or system default'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>ThemeSettingsPage(accent:blue))))),
    Card(child:ListTile(leading:const Icon(Icons.manage_accounts,color:blue),title:const Text('Account Settings'),subtitle:const Text('Login, sign out and account deletion'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>AccountSettingsPage(user:user,collection:'deliveryPartners',accent:blue,role:'delivery_partner'))))),
    Card(child:ListTile(leading:const Icon(Icons.logout),title:const Text('Sign out'),onTap:()=>FirebaseAuth.instance.signOut())),
  ]);
}
