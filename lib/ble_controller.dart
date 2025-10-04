import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class BleController extends GetxController{
  var isScanning = false.obs;
  var scanResults = <ScanResult>[].obs;
  var allScanResults = <ScanResult>[].obs; // Store all scanned devices
  var deviceStates = <String, BluetoothConnectionState>{}.obs;
  var bondedDevices = <String, bool>{}.obs; // Track paired/bonded devices
  var isBluetoothOn = false.obs;

  // Enhanced smartwatch service UUIDs
  final List<String> smartwatchServiceUUIDs = [
    "0000180d-0000-1000-8000-00805f9b34fb", // Heart Rate Service
    "0000180a-0000-1000-8000-00805f9b34fb", // Device Information Service
    "0000180f-0000-1000-8000-00805f9b34fb", // Battery Service
    "00001805-0000-1000-8000-00805f9b34fb", // Current Time Service
    "00001810-0000-1000-8000-00805f9b34fb", // Blood Pressure
    "00001818-0000-1000-8000-00805f9b34fb", // Cycling Power
    "00001816-0000-1000-8000-00805f9b34fb", // Cycling Speed and Cadence
    "00001808-0000-1000-8000-00805f9b34fb", // Glucose
    "00001809-0000-1000-8000-00805f9b34fb", // Health Thermometer
    "0000fee0-0000-1000-8000-00805f9b34fb", // Xiaomi Inc.
    "0000fee7-0000-1000-8000-00805f9b34fb", // Huawei Wearable Service
    "ae5946d4-e587-4ba8-b6a5-a97cca6affd3", // Amazfit Service

    //Bangle.js lists
    "6e400001-b5a3-f393-e0a9-e50e24dcca9e", // Nordic UART Service
    "0000feaa-0000-1000-8000-00805f9b34fb", // Eddystone
  ];

  // Common smartwatch brand names and keywords
  final List<String> smartwatchKeywords = [
    // Generic terms
    "watch", "band", "fit", "wear", "tracker", "wearable",
    
    // Major brands
    "galaxy watch", "apple watch", "wear os", "amazfit", "fitbit", 
    "garmin", "huawei watch", "honor band", "mi band", "xiaomi",
    "polar", "suunto", "fossil", "ticwatch", "samsung", "oppo watch",
    "realme watch", "noise", "boat", "fire-boltt", "oneplus watch",
    
    // Bangle.js
    "bangle", "bangle.js", "banglejs", "espruino",
    
    // Model specific
    "galaxy fit", "galaxy gear", "gear s", "active", "classic",
    "gt ", "gts", "gtr", "versa", "sense", "charge", "inspire",
    "venu", "vivoactive", "forerunner", "fenix", "instinct",
    
    // Additional patterns
    "smart watch", "smartwatch", "fitness", "health", "sport",
  ];

  // Known smartwatch manufacturer IDs (Company Identifiers)
  final List<int> smartwatchManufacturers = [
    76, // Apple Inc.
    117, // Samsung Electronics
    6, // Microsoft
    224, // Google
    343, // Xiaomi Inc.
    637, // Huawei Technologies
    706, // Amazfit
    2564, // Realme Chongqing Mobile
    2319, // Oppo Mobile
    // Add more as needed
  ];

  @override 
  void onInit() {
    super.onInit();
    //Listen to scan Results to "scanResults" variable
    FlutterBluePlus.scanResults.listen((results) {
      allScanResults.value = results;
      scanResults.value = _filterSmartwatchDevices(results);
    });
    
    // Monitor Bluetooth adapter state to update "isBluetoothOn" variable
    FlutterBluePlus.adapterState.listen((state){
      isBluetoothOn.value = (state == BluetoothAdapterState.on);
    });

    //Load bonded devices
    _loadBondedDevices();
    
    // Check Bluetooth state at initial
    checkBluetoothState();    
  }

    // Filter devices to show only smartwatches
  // Filter devices to show only smartwatches
  List<ScanResult> _filterSmartwatchDevices(List<ScanResult> results) {
    var filtered = results.where((result) {
      return _isSmartwatchDevice(result);
    }).toList();

    print(
      "🔍 Total devices: ${results.length}, Filtered smartwatches: ${filtered.length}",
    );
    return filtered;
  }

  // Enhanced smartwatch detection
  bool _isSmartwatchDevice(ScanResult result) {
    final device = result.device;
    final deviceName = device.platformName.toLowerCase();
    final advertisementData = result.advertisementData;

    // Skip devices with no name
    if (deviceName.isEmpty) {
      return false;
    }

    print("🔍 Checking: $deviceName");

    // Check 1: Device name contains smartwatch keywords
    bool nameMatch = smartwatchKeywords.any((keyword) {
      String keywordLower = keyword.toLowerCase();
      bool matches = deviceName.contains(keywordLower);
      if (matches) {
        print("   ✅ Name match: '$deviceName' contains '$keyword'");
      }
      return matches;
    });

    // Check 2: Device advertises smartwatch-related services
    bool serviceMatch = false;
    if (advertisementData.serviceUuids.isNotEmpty) {
      for (var serviceUuid in advertisementData.serviceUuids) {
        String uuidStr = serviceUuid.toString().toLowerCase();

        // Check against our smartwatch service list
        for (var knownUuid in smartwatchServiceUUIDs) {
          if (uuidStr.contains(knownUuid) || knownUuid.contains(uuidStr)) {
            serviceMatch = true;
            print("   ✅ Service match: $uuidStr");
            break;
          }
        }
        if (serviceMatch) break;
      }

      if (!serviceMatch && advertisementData.serviceUuids.isNotEmpty) {
        print(
          "   ℹ️ Services found but no match: ${advertisementData.serviceUuids.map((e) => e.toString().toLowerCase())}",
        );
      }
    }

    // Check 3: Manufacturer data for known smartwatch manufacturers
    bool manufacturerMatch = false;
    if (advertisementData.manufacturerData.isNotEmpty) {
      manufacturerMatch = advertisementData.manufacturerData.keys.any((id) {
        bool matches = smartwatchManufacturers.contains(id);
        if (matches) {
          print("   ✅ Manufacturer match: ID $id");
        }
        return matches;
      });

      if (!manufacturerMatch) {
        print(
          "   ℹ️ Manufacturer IDs: ${advertisementData.manufacturerData.keys.toList()}",
        );
      }
    }

    // Check 4: Signal strength check (smartwatches are usually close)
    bool signalStrengthOk = result.rssi > -90; // Reasonable signal strength

    // Device is considered a smartwatch if any check passes
    bool isSmartwatch =
        (nameMatch || serviceMatch || manufacturerMatch) && signalStrengthOk;

    print(
      "   ${isSmartwatch ? '✅ SMARTWATCH' : '❌ FILTERED OUT'} (Name: $nameMatch, Service: $serviceMatch, Mfr: $manufacturerMatch, RSSI: ${result.rssi})\n",
    );

    return isSmartwatch;
  }

  Future<void> _loadBondedDevices() async {
    try {
      // Get system bonded devices
      final bondedDevicesList = await FlutterBluePlus.bondedDevices;
      for (var device in bondedDevicesList) {
        bondedDevices[device.remoteId.str] = true;
      }
    } catch (e) {
      print("Error loading bonded devices: $e");
    }
  }

  Future<void> checkBluetoothState() async {
    try {
      final adapterState = await FlutterBluePlus.adapterState.first;
      isBluetoothOn.value = (adapterState == BluetoothAdapterState.on);
      
      if (!isBluetoothOn.value) {
        Get.snackbar(
          "Bluetooth is Off",
          "Please enable Bluetooth to scan for devices",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 4),
          mainButton: TextButton(
            onPressed: () => requestEnableBluetooth(),
            child: const Text(
              "Enable",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      print("Error checking Bluetooth state: $e");
    }
  }
  Future<void> requestEnableBluetooth() async {
    try {
      if (GetPlatform.isAndroid) {
        try {
          // This will trigger the system Bluetooth permission dialog
          await FlutterBluePlus.turnOn();

          // Give the system a moment to process
          await Future.delayed(const Duration(milliseconds: 1000));

          // Check if Bluetooth is now on
          final adapterState = await FlutterBluePlus.adapterState.first;

          print("🔵 Adapter state after turnOn: $adapterState");

          if (adapterState == BluetoothAdapterState.on) {
            Get.snackbar(
              "Bluetooth Enabled",
              "Bluetooth has been turned on successfully",
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.green,
              colorText: Colors.white,
              margin: const EdgeInsets.all(12),
              duration: const Duration(seconds: 2),
              icon: const Icon(Icons.bluetooth_connected, color: Colors.white),
            );
          } else {
            print("🔵 Bluetooth still off, showing manual dialog");
            _showManualEnableDialog();
          }
        } catch (e) {
          print("❌ Error turning on Bluetooth: $e");
          _showManualEnableDialog();
        }
    } else if (GetPlatform.isIOS) {
      _showManualEnableDialog();
    }

    }catch(e){
      print("Error requesting Bluetooth enable: $e");
      Get.snackbar(
        "Error",
        "Failed to enable Bluetooth: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _showManualEnableDialog() {
    Get.dialog(
      AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings_bluetooth, color: Colors.orange),
            SizedBox(width: 8),
            Text("Manual Action Required"),
          ],
        ),
        content: const Text(
          "Please enable Bluetooth manually in your device settings to use this app.",
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Get.back();
              await openBluetoothSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text("Open Settings"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> openBluetoothSettings() async {
    try {
      // Open app settings where user can enable Bluetooth
      await openAppSettings();
    } catch (e) {
      Get.snackbar(
        "Error",
        "Could not open settings: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> scanDevice() async {
    // Check if Bluetooth is supported and enabled
    if (!await FlutterBluePlus.isSupported) {
      Get.snackbar(
        "Not Supported",
        "Bluetooth is not supported on this device",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Check Bluetooth adapter state
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      await requestEnableBluetooth();
      return;
    }

    // Request permissions
    var scanPermission = await Permission.bluetoothScan.request();
    var conPermission = await Permission.bluetoothConnect.request();
    var locationPermission = await Permission.location.request();

    if (scanPermission.isGranted && 
        conPermission.isGranted && 
        locationPermission.isGranted) {
      
      try {
        // Clear previous results
        scanResults.clear();
        allScanResults.clear();
        isScanning.value = true;
        
        // Start scanning with service UUIDs filter (optional - can help reduce scan results)
        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 10),
          // You can add service UUIDs here to filter at hardware level
          // withServices: smartwatchServiceUUIDs.map((uuid) => Guid(uuid)).toList(),
        );
        
        // Wait for scan to complete
        await Future.delayed(const Duration(seconds: 10));
        
        // Stop scanning
        await FlutterBluePlus.stopScan();
        isScanning.value = false;
        
        // Show result count
        if (scanResults.isEmpty) {
          Get.snackbar(
            "No Smartwatches Found",
            "No smartwatch devices detected. Make sure your smartwatch is in pairing mode and nearby.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 4),
          );
        } else {
          Get.snackbar(
            "Scan Complete",
            "Found ${scanResults.length} smartwatch device(s)",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 2),
          );
        }
        
        // Refresh bonded devices after scan
        await _loadBondedDevices();
        
      } catch (e) {
        isScanning.value = false;
        Get.snackbar(
          "Scan Error",
          "Failed to scan: $e",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3),
        );
      }
    } else {
      Get.snackbar(
        "Permission Denied",
        "Bluetooth permissions not granted",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> pairDevice(BluetoothDevice device) async {
    try {
      final deviceId = device.remoteId.str;
      
      // Check if already bonded
      if (bondedDevices[deviceId] == true) {
        Get.snackbar(
          "Already Paired",
          "Device is already paired: ${device.platformName.isNotEmpty ? device.platformName : 'Unknown Device'}",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        );
        return;
      }

      // Show pairing in progress
      Get.snackbar(
        "Pairing",
        "Pairing with: ${device.platformName.isNotEmpty ? device.platformName : 'Unknown Device'}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      );

      // First connect to the device
      await device.connect(timeout: const Duration(seconds: 15));
      
      // Create bond (pair)
      await device.createBond();
      
      // Update our bonded devices map
      bondedDevices[deviceId] = true;

      Get.snackbar(
        "Paired Successfully",
        "Device paired: ${device.platformName.isNotEmpty ? device.platformName : 'Unknown Device'}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );

      // Listen for connection state changes
      device.connectionState.listen((state) {
        deviceStates[deviceId] = state;
      });

    } catch (e) {
      Get.snackbar(
        "Pairing Failed",
        "Failed to pair device: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> unpairDevice(BluetoothDevice device) async {
    try {
      final deviceId = device.remoteId.str;
      
      // Remove bond
      await device.removeBond();
      
      // Disconnect if connected
      if (deviceStates[deviceId] == BluetoothConnectionState.connected) {
        await device.disconnect();
      }
      
      // Update our maps
      bondedDevices[deviceId] = false;
      deviceStates[deviceId] = BluetoothConnectionState.disconnected;

      Get.snackbar(
        "Unpaired Successfully",
        "Device unpaired: ${device.platformName.isNotEmpty ? device.platformName : 'Unknown Device'}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      );

    } catch (e) {
      Get.snackbar(
        "Unpair Failed",
        "Failed to unpair device: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      final deviceId = device.remoteId.str;
      
      // Check current state first
      final currentState = await device.connectionState.first;
      if (currentState == BluetoothConnectionState.connected) {
        Get.snackbar(
          "Already Connected",
          "Device is already connected: ${device.platformName.isNotEmpty ? device.platformName : 'Unknown Device'}",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        );
        deviceStates[deviceId] = BluetoothConnectionState.connected;
        return;
      }

      // Set connecting state
      deviceStates[deviceId] = BluetoothConnectionState.connecting;
      
      // Connect to device
      await device.connect(timeout: const Duration(seconds: 15));
      deviceStates[deviceId] = BluetoothConnectionState.connected;

      Get.snackbar(
        "Connected",
        "Device connected: ${device.platformName.isNotEmpty ? device.platformName : 'Unknown Device'}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      );

    } catch (e) {
      deviceStates[device.remoteId.str] = BluetoothConnectionState.disconnected;
      Get.snackbar(
        "Connection Error",
        "Failed to connect: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      deviceStates[device.remoteId.str] = BluetoothConnectionState.disconnected;
    } catch (e) {
      Get.snackbar(
        "Disconnect Error",
        "Failed to disconnect: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      );
    }
  }

  BluetoothConnectionState getDeviceState(String deviceId) {
    return deviceStates[deviceId] ?? BluetoothConnectionState.disconnected;
  }

  bool isDevicePaired(String deviceId) {
    return bondedDevices[deviceId] ?? false;
  }

  // Helper method to check if device is smartwatch (for debugging)
  String getDeviceType(ScanResult result) {
    bool isSmartwatch = _isSmartwatchDevice(result);
    return isSmartwatch ? "Smartwatch" : "Other Device";
  }

  // Method to toggle filter (optional - for future enhancement)
  var filterEnabled = true.obs;
  
  void toggleFilter() {
    filterEnabled.value = !filterEnabled.value;
    if (filterEnabled.value) {
      scanResults.value = _filterSmartwatchDevices(allScanResults);
    } else {
      scanResults.value = allScanResults;
    }
  }

  // Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  // =========== Old version ====================
  // Future<void> scanDevice() async{
  //   var scanPermission = await Permission.bluetoothScan.request();
  //   var conPermission = await Permission.bluetoothConnect.request();
  //   var locationPermission = await Permission.location.request();

  //   if(scanPermission.isGranted && conPermission.isGranted && locationPermission.isGranted){

  //     FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  //     Future.delayed(const Duration(seconds: 10), () {
  //       FlutterBluePlus.stopScan();
  //       isScanning.value = true;
  //     });

  //   }else {
  //     Get.snackbar(
  //       "Permission Denied",
  //       "Bluetooth permission not granted",
  //       snackPosition: SnackPosition.BOTTOM,
  //       backgroundColor: Colors.red,
  //       colorText: Colors.white,
  //       margin: const EdgeInsets.all(12),
  //       duration: const Duration(seconds: 3),
  //     );
  //   }
  // }



    // Future<void> requestEnableBluetooth() async {
  //   try {
  //     // Show confirmation dialog first
  //     bool? shouldEnable = await Get.dialog<bool>(
  //       AlertDialog(
  //         title: const Row(
  //           children: [
  //             Icon(Icons.bluetooth, color: Colors.blue),
  //             SizedBox(width: 8),
  //             Text("Enable Bluetooth"),
  //           ],
  //         ),
  //         content: const Text(
  //           "This app needs Bluetooth to be turned on to scan and connect to devices. Would you like to enable it?",
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Get.back(result: false),
  //             child: const Text("Cancel"),
  //           ),
  //           ElevatedButton(
  //             onPressed: () => Get.back(result: true),
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: Colors.blue,
  //               foregroundColor: Colors.white,
  //             ),
  //             child: const Text("Turn On"),
  //           ),
  //         ],
  //       ),
  //     );

  //     if (shouldEnable != true) {
  //       return print("User declined to enable Bluetooth");
  //     }

  //     // Request to turn on Bluetooth
  //     // On Android 12 and below: Shows system permission dialog
  //     // On Android 13+: May require manual enabling in settings
  //     if (GetPlatform.isAndroid) {
  //       try {
  //         // This will trigger the system Bluetooth permission dialog
  //         await FlutterBluePlus.turnOn();
          
  //         // Give the system a moment to process
  //         await Future.delayed(const Duration(milliseconds: 1000));
          
  //         // Check if Bluetooth is now on
  //         final adapterState = await FlutterBluePlus.adapterState.first;
          
  //         if (adapterState == BluetoothAdapterState.on) {
  //           Get.snackbar(
  //             "Bluetooth Enabled",
  //             "Bluetooth has been turned on successfully",
  //             snackPosition: SnackPosition.BOTTOM,
  //             backgroundColor: Colors.green,
  //             colorText: Colors.white,
  //             margin: const EdgeInsets.all(12),
  //             duration: const Duration(seconds: 2),
  //             icon: const Icon(Icons.bluetooth_connected, color: Colors.white),
  //           );
  //         } else {
  //           // If still off after turnOn attempt (Android 13+)
  //           _showManualEnableDialog();
  //         }
  //       } catch (e) {
  //         // If turnOn() fails, show manual enable dialog
  //         _showManualEnableDialog();
  //       }
  //     } else if (GetPlatform.isIOS) {
  //       // iOS doesn't allow programmatic Bluetooth control
  //       _showManualEnableDialog();
  //     }
  //   } catch (e) {
  //     Get.snackbar(
  //       "Error",
  //       "Failed to enable Bluetooth: ${e.toString()}",
  //       snackPosition: SnackPosition.BOTTOM,
  //       backgroundColor: Colors.red,
  //       colorText: Colors.white,
  //       margin: const EdgeInsets.all(12),
  //       duration: const Duration(seconds: 3),
  //     );
  //   }
  // }
}