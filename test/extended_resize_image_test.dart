import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:extended_image_library/extended_image_library.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Size = (int?, int?);
typedef _ResizeCase =
    ({
      String name,
      ResizeImagePolicy policy,
      int? width,
      int? height,
      bool allowUpscaling,
      _Size expected,
    });

final Uint8List _probeBytes = Uint8List(1);
final MemoryImage _source = MemoryImage(_probeBytes);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ResizeImagePolicy? cover = _coverPolicy();

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  final List<_ResizeCase> existingCases = <_ResizeCase>[
    (
      name: 'exact',
      policy: ResizeImagePolicy.exact,
      width: 150,
      height: 150,
      allowUpscaling: false,
      expected: (150, 150),
    ),
    (
      name: 'exact single side',
      policy: ResizeImagePolicy.exact,
      width: 150,
      height: null,
      allowUpscaling: false,
      expected: (150, null),
    ),
    (
      name: 'exact clamps both sides',
      policy: ResizeImagePolicy.exact,
      width: 400,
      height: 400,
      allowUpscaling: false,
      expected: (300, 200),
    ),
    (
      name: 'exact permits upscaling',
      policy: ResizeImagePolicy.exact,
      width: 400,
      height: 400,
      allowUpscaling: true,
      expected: (400, 400),
    ),
    (
      name: 'fit preserves aspect ratio',
      policy: ResizeImagePolicy.fit,
      width: 150,
      height: 150,
      allowUpscaling: false,
      expected: (150, 100),
    ),
    (
      name: 'fit single side',
      policy: ResizeImagePolicy.fit,
      width: null,
      height: 90,
      allowUpscaling: false,
      expected: (135, 90),
    ),
    (
      name: 'fit does not upscale',
      policy: ResizeImagePolicy.fit,
      width: 450,
      height: 450,
      allowUpscaling: false,
      expected: (300, 200),
    ),
    (
      name: 'fit permits upscaling',
      policy: ResizeImagePolicy.fit,
      width: 450,
      height: 450,
      allowUpscaling: true,
      expected: (450, 300),
    ),
  ];
  for (final _ResizeCase scenario in existingCases) {
    test(scenario.name, () async {
      final ImageProvider<Object> provider = ExtendedResizeImage(
        _source,
        maxBytes: null,
        width: scenario.width,
        height: scenario.height,
        policy: scenario.policy,
        allowUpscaling: scenario.allowUpscaling,
      );
      expect(await _targetSize(provider, 300, 200), scenario.expected);
    });
  }

  group('cover', () {
    test('covers a square without distorting a landscape image', () async {
      expect(await _targetSize(_coverImage(cover!, 150, 150), 300, 200), (
        225,
        150,
      ));
    });
    test('covers a square without distorting a portrait image', () async {
      expect(await _targetSize(_coverImage(cover!, 150, 150), 200, 300), (
        150,
        225,
      ));
    });
    test('preserves original size when upscaling is disabled', () async {
      expect(await _targetSize(_coverImage(cover!, 400, 400), 300, 200), (
        null,
        null,
      ));
    });
    test('upscales proportionally when explicitly enabled', () async {
      expect(
        await _targetSize(
          _coverImage(cover!, 400, 400, allowUpscaling: true),
          300,
          200,
        ),
        (600, 400),
      );
    });
    test(
      'uses integer ceiling without overshooting exact dimensions',
      () async {
        expect(await _targetSize(_coverImage(cover!, 448, 100), 3000, 2000), (
          448,
          299,
        ));
        expect(await _targetSize(_coverImage(cover, 448, 448), 3000, 2000), (
          672,
          448,
        ));
      },
    );
    test('retains a positive derived side for a one-pixel target', () async {
      expect(await _targetSize(_coverImage(cover!, 1, 1), 1000, 2000), (1, 2));
    });
    test(
      'matches Flutter across aspect ratios and upscaling settings',
      () async {
        for (final (int, int) sourceSize in <(int, int)>[
          (300, 200),
          (200, 300),
          (3000, 2000),
          (1, 1000),
          (1000, 1),
        ]) {
          for (final (int, int) box in <(int, int)>[
            (150, 150),
            (448, 100),
            (1, 1),
            (400, 500),
          ]) {
            for (final bool upscale in <bool>[false, true]) {
              final ImageProvider<Object> reference = ResizeImage(
                _source,
                width: box.$1,
                height: box.$2,
                policy: cover!,
                allowUpscaling: upscale,
              );
              final ImageProvider<Object> actual = _coverImage(
                cover,
                box.$1,
                box.$2,
                allowUpscaling: upscale,
              );
              expect(
                await _targetSize(actual, sourceSize.$1, sourceSize.$2),
                await _targetSize(reference, sourceSize.$1, sourceSize.$2),
                reason: 'source=$sourceSize box=$box upscale=$upscale',
              );
            }
          }
        }
      },
    );
    test('rejects missing or non-positive target dimensions', () async {
      for (final _Size box in <_Size>[
        (null, 100),
        (100, null),
        (0, 100),
        (100, 0),
        (-1, 100),
        (100, -1),
      ]) {
        await expectLater(
          _targetSize(_coverImage(cover!, box.$1, box.$2), 300, 200),
          throwsArgumentError,
        );
      }
    });
  }, skip: cover == null);

  test('provider and cache keys distinguish resize policies', () async {
    final ImageProvider<Object> exact = ExtendedResizeImage(
      _source,
      width: 100,
      height: 100,
      policy: ResizeImagePolicy.exact,
    );
    final ImageProvider<Object> fit = ExtendedResizeImage(
      _source,
      width: 100,
      height: 100,
      policy: ResizeImagePolicy.fit,
    );
    expect(exact, isNot(fit));
    expect(
      await exact.obtainKey(ImageConfiguration.empty),
      isNot(await fit.obtainKey(ImageConfiguration.empty)),
    );
  });
  test(
    'cache keys distinguish upscaling and preserve equivalent providers',
    () async {
      final ImageProvider<Object> first = _coverImage(
        cover ?? ResizeImagePolicy.fit,
        100,
        100,
      );
      final ImageProvider<Object> equal = _coverImage(
        cover ?? ResizeImagePolicy.fit,
        100,
        100,
      );
      final ImageProvider<Object> upscale = _coverImage(
        cover ?? ResizeImagePolicy.fit,
        100,
        100,
        allowUpscaling: true,
      );
      final Object key = await first.obtainKey(ImageConfiguration.empty);
      final Object equalKey = await equal.obtainKey(ImageConfiguration.empty);
      expect(first, equal);
      expect(first.hashCode, equal.hashCode);
      expect(key, equalKey);
      expect(key.hashCode, equalKey.hashCode);
      expect(key, isNot(await upscale.obtainKey(ImageConfiguration.empty)));
    },
  );
  test('actual decoded images retain exact and fit behavior', () async {
    final MemoryImage source = MemoryImage(await _imageBytes());
    expect(
      await _decodedSize(
        ExtendedResizeImage(source, maxBytes: null, width: 6, height: 6),
      ),
      (6, 6),
    );
    expect(
      await _decodedSize(
        ExtendedResizeImage(
          source,
          maxBytes: null,
          width: 6,
          height: 6,
          policy: ResizeImagePolicy.fit,
        ),
      ),
      (6, 4),
    );
  });
  test(
    'cached fit images cannot satisfy cover or a different upscaling option',
    () async {
      final MemoryImage source = MemoryImage(await _imageBytes());
      expect(
        await _decodedSize(
          ExtendedResizeImage(
            source,
            maxBytes: null,
            width: 6,
            height: 6,
            policy: ResizeImagePolicy.fit,
          ),
        ),
        (6, 4),
      );
      expect(
        await _decodedSize(
          ExtendedResizeImage(
            source,
            maxBytes: null,
            width: 6,
            height: 6,
            policy: cover!,
          ),
        ),
        (9, 6),
      );
      expect(
        await _decodedSize(
          ExtendedResizeImage(
            source,
            maxBytes: null,
            width: 18,
            height: 18,
            policy: cover,
          ),
        ),
        (12, 8),
      );
      expect(
        await _decodedSize(
          ExtendedResizeImage(
            source,
            maxBytes: null,
            width: 18,
            height: 18,
            policy: cover,
            allowUpscaling: true,
          ),
        ),
        (27, 18),
      );
    },
    skip: cover == null,
  );
  test(
    'compression ratio keeps precedence over explicit decode dimensions',
    () async {
      final MemoryImage source = MemoryImage(await _imageBytes());
      expect(
        await _decodedSize(
          ExtendedResizeImage(
            source,
            compressionRatio: 0.25,
            width: 1,
            height: 1,
            policy: cover ?? ResizeImagePolicy.fit,
          ),
        ),
        (6, 4),
      );
    },
  );
}

ResizeImagePolicy? _coverPolicy() {
  for (final ResizeImagePolicy policy in ResizeImagePolicy.values) {
    if (policy.name == 'cover') {
      return policy;
    }
  }
  return null;
}

ImageProvider<Object> _coverImage(
  ResizeImagePolicy policy,
  int? width,
  int? height, {
  bool allowUpscaling = false,
}) => ExtendedResizeImage(
  _source,
  maxBytes: null,
  width: width,
  height: height,
  policy: policy,
  allowUpscaling: allowUpscaling,
);

Future<_Size> _targetSize(
  ImageProvider<Object> provider,
  int width,
  int height,
) async {
  final Completer<_Size> result = Completer<_Size>();
  final Object key = await provider.obtainKey(ImageConfiguration.empty);
  final ImageStreamCompleter stream = _DecoderProbe(provider).start(key, (
    ui.ImmutableBuffer buffer, {
    ui.TargetImageSizeCallback? getTargetSize,
  }) async {
    try {
      final ui.TargetImageSize size = getTargetSize!(width, height);
      result.complete((size.width, size.height));
    } catch (error, stackTrace) {
      result.completeError(error, stackTrace);
    } finally {
      buffer.dispose();
    }
    return _ProbeCodec();
  });
  final ImageStreamCompleterHandle handle = stream.keepAlive();
  try {
    return await result.future;
  } finally {
    await Future<void>.delayed(Duration.zero);
    handle.dispose();
  }
}

Future<Uint8List> _imageBytes() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xFF336699), ui.BlendMode.src);
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(12, 8);
  try {
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<_Size> _decodedSize(ImageProvider<Object> provider) async {
  final Completer<_Size> result = Completer<_Size>();
  final ImageStream stream = provider.resolve(ImageConfiguration.empty);
  final ImageStreamListener listener = ImageStreamListener((
    ImageInfo info,
    bool synchronous,
  ) {
    result.complete((info.image.width, info.image.height));
    info.dispose();
  }, onError: result.completeError);
  stream.addListener(listener);
  try {
    return await result.future;
  } finally {
    stream.removeListener(listener);
  }
}

class _ProbeCodec extends Fake implements ui.Codec {
  @override
  void dispose() {}
}

class _DecoderProbe extends ImageProvider<Object> {
  const _DecoderProbe(this.provider);

  final ImageProvider<Object> provider;

  @override
  Future<Object> obtainKey(ImageConfiguration configuration) =>
      provider.obtainKey(configuration);

  ImageStreamCompleter start(Object key, ImageDecoderCallback decode) =>
      provider.loadImage(key, decode);
}
