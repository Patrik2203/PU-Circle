// Future<T> retry<T>(
//     Future<T> Function() fn, {
//       int maxRetries = 3,
//       Duration delay = const Duration(seconds: 1),
//     }) async {
//   int attempts = 0;
//   while (true) {
//     try {
//       attempts++;
//       return await fn();
//     } catch (e) {
//       if (attempts >= maxRetries) rethrow;
//
//       // Only retry for network-related errors
//       if (e.toString().contains('unavailable') ||
//           e.toString().contains('network') ||
//           e.toString().contains('connection')) {
//         await Future.delayed(delay * attempts); // Exponential backoff
//         continue;
//       }
//       rethrow;
//     }
//   }
// }