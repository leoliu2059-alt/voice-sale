update storage.buckets
set allowed_mime_types = array[
  'audio/aac',
  'audio/aiff',
  'audio/flac',
  'audio/mp3',
  'audio/mp4',
  'audio/mpeg',
  'audio/wave',
  'audio/webm',
  'audio/wav',
  'audio/x-aac',
  'audio/x-aiff',
  'audio/x-caf',
  'audio/x-flac',
  'audio/x-m4a',
  'audio/x-wav',
  'video/mp4',
  'video/quicktime'
]
where id = 'call-audio';
