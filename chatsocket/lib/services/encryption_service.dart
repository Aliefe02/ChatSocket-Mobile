import 'dart:convert';
import 'package:pointycastle/export.dart';
import 'package:asn1lib/asn1lib.dart';
import 'dart:typed_data';

class EncryptionService {
  Future<Map<String, String>> createKeys() async {
    final keyParams = RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 5);
    final secureRandom = FortunaRandom();
    final random = DateTime.now().millisecondsSinceEpoch;
    secureRandom.seed(
      KeyParameter(Uint8List.fromList(List.generate(32, (_) => random % 256))),
    );

    final keyGenerator =
        RSAKeyGenerator()..init(ParametersWithRandom(keyParams, secureRandom));

    final pair = keyGenerator.generateKeyPair();
    final RSAPublicKey publicKey = pair.publicKey as RSAPublicKey;
    final RSAPrivateKey privateKey = pair.privateKey as RSAPrivateKey;

    // Encode keys to Base64 strings
    final publicPem = _encodePublicKeyToPem(publicKey);
    final privatePem = _encodePrivateKeyToPem(privateKey);

    return {'publicKey': publicPem, 'privateKey': privatePem};
  }

  String _encodePublicKeyToPem(RSAPublicKey publicKey) {
    final algorithmSeq =
        ASN1Sequence()
          ..add(ASN1ObjectIdentifier.fromName('rsaEncryption'))
          ..add(ASN1Null());
    final publicKeySeq =
        ASN1Sequence()
          ..add(ASN1Integer(publicKey.modulus!))
          ..add(ASN1Integer(publicKey.exponent!));
    final publicKeyBitString = ASN1BitString(
      Uint8List.fromList(publicKeySeq.encodedBytes),
    );
    final topLevelSeq =
        ASN1Sequence()
          ..add(algorithmSeq)
          ..add(publicKeyBitString);
    return base64.encode(topLevelSeq.encodedBytes);
  }

  String _encodePrivateKeyToPem(RSAPrivateKey privateKey) {
    final privateKeySeq =
        ASN1Sequence()
          ..add(ASN1Integer(BigInt.from(0))) // version
          ..add(ASN1Integer(privateKey.n!))
          ..add(ASN1Integer(privateKey.exponent!)) // privateExponent
          ..add(ASN1Integer(privateKey.p!))
          ..add(ASN1Integer(privateKey.q!))
          ..add(
            ASN1Integer(
              privateKey.privateExponent! % (privateKey.p! - BigInt.one),
            ),
          ) // d mod (p-1)
          ..add(
            ASN1Integer(
              privateKey.privateExponent! % (privateKey.q! - BigInt.one),
            ),
          ) // d mod (q-1)
          ..add(
            ASN1Integer(privateKey.q!.modInverse(privateKey.p!)),
          ); // CRT coefficient
    return base64.encode(privateKeySeq.encodedBytes);
  }

  Future<String> encryptMessage(
    String plainText,
    String recipientPublicKey,
  ) async {
    // TODO: Encrypt the message using publicKey
    return '';
  }

  Future<String> decryptMessage(String encryptedMessage) async {
    // TODO: Decrypt using stored privateKey
    return '';
  }
}
