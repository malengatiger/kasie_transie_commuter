import 'package:flutter/material.dart';
import 'package:kasie_transie_library/utils/functions.dart';
import 'package:kasie_transie_library/data/schemas.dart' as lib;

class CommuterQrCode extends StatelessWidget {
  const CommuterQrCode(
      {Key? key, required this.commuter, required this.onClose})
      : super(key: key);

  final lib.Commuter commuter;
  final Function onClose;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // height: 640,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GestureDetector(
          onTap: () {
            onClose();
          },
          child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                const SizedBox(height: 64,),
                Expanded(
                  child: Card(
                    shape: getRoundedBorder(radius: 16),
                    elevation: 12,
                    child: Column(
                      children: [
                        Text(
                          'Commuter QR Code',
                          style: myTextStyleMediumLargeWithColor(
                              context, Theme.of(context).primaryColor, 24),
                        ),
                        const SizedBox(
                          height: 24,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Image.network(commuter.qrCodeUrl!),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
