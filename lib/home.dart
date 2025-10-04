// import 'package:bluetooth_low_energy/ble_controller.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
// import 'package:get/get.dart';

// void main() {
//   runApp(const MyApp());
// }


//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//       ),
//       home: const MyHomePage(title: 'Flutter Demo Home Page'),
//     );
//   }
// }

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         title: const Text("First Bluetooth"),
//       ),
//       body: GetBuilder<BleController>(
//         init: BleController(),
//         builder: (BleController controller) {
//           return Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 StreamBuilder<List<ScanResult>>(
//                   stream: controller.scanResults,
//                   builder: (context, snapshot) {
//                     if (snapshot.hasData && snapshot.data!.isNotEmpty)  {
//                       return Expanded(
//                         child: ListView.builder(
//                           itemCount: snapshot.data!.length,
//                           itemBuilder: (context, index) {
//                             final data = snapshot.data![index];
//                             return Card(
//                               elevation: 3,
//                               color: Color.fromARGB(255, 79, 199, 255),
//                               child: ListTile(
//                                 leading: Icon(Icons.bluetooth),
//                                 title: Text(
//                                   data.device.platformName.isNotEmpty
//                                       ? data.device.platformName
//                                       : "Unknown Device",
//                                 ),
//                                 subtitle: Text(data.device.remoteId.toString()),
//                                 trailing: Text("${data.rssi} dBm"),
//                                 onTap: () {
//                                   controller.connectToDevice(data.device);
//                                 }
//                               ),
//                             );
//                           },
//                         ),
//                       );
//                     } else if (controller.isScanning.value && snapshot.data!.isEmpty) {
//                       return const Text("No Device Found");
//                     } else {
//                       return const SizedBox();
//                     }
//                   },
//                 ),
//                 SizedBox(height: 20),

//                 ElevatedButton(
//                   onPressed: () => {
//                     controller.scanDevice()
//                   },
//                   child: const Text("Scan"),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
