/// Largest proof photo that may be uploaded.
const int maxProofPhotoBytes = 5 * 1024 * 1024;

const _allowedPhotoTypes = {'jpg', 'jpeg', 'png', 'webp', 'heic'};

/// Whether a picked file can be uploaded as a proof photo: an image type we
/// accept and no larger than [maxProofPhotoBytes].
bool isAcceptableProofPhoto({required String fileName, required int bytes}) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return false;
  final ext = fileName.substring(dot + 1).toLowerCase();
  return _allowedPhotoTypes.contains(ext) &&
      bytes > 0 &&
      bytes <= maxProofPhotoBytes;
}

const _allowedAttachmentTypes = {..._allowedPhotoTypes, 'pdf'};

/// Whether a picked file can be attached to a ticket: an image type we accept
/// or a PDF, and no larger than [maxProofPhotoBytes] (5 MB).
bool isAcceptableAttachment({required String fileName, required int bytes}) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return false;
  final ext = fileName.substring(dot + 1).toLowerCase();
  return _allowedAttachmentTypes.contains(ext) &&
      bytes > 0 &&
      bytes <= maxProofPhotoBytes;
}
