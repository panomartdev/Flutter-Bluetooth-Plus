import 'package:bluetooth_low_energy/ble_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("First Bluetooth"),
      ),
      body: GetX<BleController>(
        init: BleController(),
        builder: (BleController controller){
          return Column(
            children:[
              //========= Bluetooth On/Off banner ==========
              Obx(() {
                if(!controller.isBluetoothOn.value){
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Colors.orange),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bluetooth_disabled,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Bluetooth is turned off",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => controller.requestEnableBluetooth(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: const Text("Turn On"),
                        ),
                      ],
                    ),
                  );
                }else {
                  return const SizedBox.shrink();
                }
              }),
              //========= Loading Header ==========
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                child: controller.isScanning.value
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Scanning for devices...",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        "Found ${controller.scanResults.length} device(s)",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                    ),
              ),

              //======== Device List =========
              Expanded(
                child: controller.scanResults.isNotEmpty ?
                  //=== Device Found Condition ===
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: controller.scanResults.length,
                    itemBuilder: (context, index){
                      final data = controller.scanResults[index];
                      final deviceId = data.device.remoteId.str;
                      final deviceState = controller.getDeviceState(deviceId);
                      final isPaired = controller.isDevicePaired(deviceId);
                      final deviceName = data.device.platformName.isNotEmpty ? data.device.platformName : "Unknown Device";

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: isPaired ? Colors.blue[50]: Colors.white,
                          border: Border.all(
                            color: isPaired ? Colors.blue[200]! : Colors.grey[300]!,
                            width: isPaired ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isPaired ? Colors.blue[100] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getDeviceIcon(deviceState, isPaired),
                              color: isPaired ? Colors.blue[700] : Colors.grey[600],
                              size: 24,
                            ),
                          ),
                          title: Text(
                            deviceName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isPaired ? Colors.blue[800] : Colors.black87
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:[
                              const SizedBox(height: 4),
                              Text(
                                "ID: ${deviceId.substring(0, 8)}...",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                )
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children:[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(deviceState, isPaired),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getStatusText(deviceState, isPaired),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      )
                                    )
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${data.rssi} dBm",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    )
                                  ),
                                ]
                              )
                            ]
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Pair/Unpair button
                              if(!isPaired)
                                ElevatedButton.icon(
                                  onPressed: () => controller.pairDevice(data.device),
                                  icon: const Icon(Icons.link , size: 16),
                                  label: const Text("Pair"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    textStyle: const TextStyle(fontSize: 12),
                                  )
                                )
                              else ...[
                                // Connect or Disconnect button for paired devices
                                if(deviceState == BluetoothConnectionState.connected)
                                  ElevatedButton.icon(
                                    onPressed: () => controller.disconnectDevice(data.device),
                                    icon: const Icon(Icons.link_off, size: 16),
                                    label: const Text("Disconnect"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      textStyle: const TextStyle(fontSize: 12)
                                    )
                                  )
                                else 
                                  ElevatedButton.icon(
                                    onPressed: () => controller.unpairDevice(data.device),
                                    icon: const Icon(Icons.link, size: 16),
                                    label: const Text("Connect"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ]
                            ]
                          ),
                        )
                      );
                    }
                  ): 
                  //=== No Device Found Condition ===
                  Center( // TODO LATER
                    child: Text(
                      controller.isScanning.value ? "Scanning..." : "No Device Found",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
              )
            ]
          );
        }

      ),
      floatingActionButton: GetX<BleController>(
        builder: (controller) => FloatingActionButton.extended(
          onPressed: () => controller.isScanning.value ? null : controller.scanDevice(),
          icon: const Icon(Icons.search),
          label: Text(
            controller.isScanning.value ? "Scanning" : "Scan for Device",
           
          ),
          backgroundColor: controller.isScanning.value ? Colors.grey : Colors.blue,
          foregroundColor: Colors.white,
        )
      ),
    );
  }

  //===== Device Icon Function ====
  IconData _getDeviceIcon(BluetoothConnectionState state, bool isPaired) {
    if (isPaired) {
      switch (state) {
        case BluetoothConnectionState.connected:
          return Icons.bluetooth_connected;
        default:
          return Icons.bluetooth;
      }
    } else {
      return Icons.bluetooth_disabled;
    }
  }

  //==== Status Color Function ====
  Color _getStatusColor(BluetoothConnectionState state, bool isPaired) {
    if (!isPaired) {
      return Colors.grey;
    }

    switch (state) {
      case BluetoothConnectionState.connected:
        return Colors.green;
      case BluetoothConnectionState.connecting:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  //==== Status Text Function ====
  String _getStatusText(BluetoothConnectionState state, bool isPaired) {
    if (!isPaired) {
      return "Not Paired";
    }

    switch (state) {
      case BluetoothConnectionState.connected:
        return "Paired & Connected";
      default:
        return "Paired";
    }
  }
}
