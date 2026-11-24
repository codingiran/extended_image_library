# extended_image_library

[![pub package](https://img.shields.io/pub/v/extended_image_library.svg)](https://pub.dartlang.org/packages/extended_image_library)

package library for extended_image

## Zurbo compatibility fork

This fork retains the upstream 5.0.1 API and minimum SDK requirements while
supporting Flutter SDKs that add `ResizeImagePolicy.cover`. The cover policy
uses Flutter's integer-ceiling sizing and upscaling behavior; existing `exact`,
`fit`, compression and byte-limit behavior is preserved. Resize policies and
upscaling options have independent image cache keys.

Run `flutter test` using both the existing stable SDK and the newer SDK. Cover
tests discover the enum value by name and are skipped on SDKs without it.
Consumers should pin the compatibility commit rather than a moving branch.

# extended_image

[![pub package](https://img.shields.io/pub/v/extended_image.svg)](https://pub.dartlang.org/packages/extended_image)

A powerful official extension library of image, which support placeholder(loading)/ failed state, cache network, zoom pan image, photo view, slide out page, editor(crop,rotate,flip), paint custom etc.

![img](https://github.com/fluttercandies/Flutter_Candies/blob/master/gif/extended_image/editor.gif)

