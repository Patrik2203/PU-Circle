// Widget _buildCommentSection() {
//   return Padding(
//     padding: const EdgeInsets.symmetric(horizontal: 16),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // View all comments button
//         TextButton(
//           onPressed: () {
//             // Navigate to comments page
//           },
//           style: TextButton.styleFrom(
//             padding: EdgeInsets.zero,
//             alignment: Alignment.centerLeft,
//             minimumSize: Size.zero,
//             tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//           ),
//           child: Text(
//             'View all comments',
//             style: TextStyle(color: Colors.grey[600], fontSize: 14),
//           ),
//         ),
//
//         // Add comment field
//         Row(
//           children: [
//             CircleAvatar(
//               radius: 16,
//               backgroundColor: Colors.grey[200],
//               backgroundImage:
//                   _currentUserId.isNotEmpty
//                       ? const NetworkImage(
//                         '',
//                       ) // Replace with current user profile image
//                       : null,
//               child:
//                   _currentUserId.isEmpty
//                       ? const Icon(Icons.person, size: 16)
//                       : null,
//             ),
//             const SizedBox(width: 8),
//             Expanded(
//               child: TextField(
//                 decoration: InputDecoration(
//                   hintText: ' Add a comment...',
//                   hintStyle: TextStyle(color: Colors.grey[500]),
//                   border: InputBorder.none,
//                   isDense: true,
//                   contentPadding: const EdgeInsets.symmetric(vertical: 8),
//                 ),
//                 style: const TextStyle(fontSize: 14),
//               ),
//             ),
//             TextButton(
//               onPressed: () {
//                 // Post comment
//               },
//               style: TextButton.styleFrom(
//                 padding: EdgeInsets.zero,
//                 minimumSize: Size.zero,
//               ),
//               child: Text(
//                 'Post',
//                 style: TextStyle(
//                   color: AppColors.primary,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 14,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ],
//     ),
//   );
// }