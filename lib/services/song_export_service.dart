import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/entities/song.dart';

class SongExportOptions {
  const SongExportOptions({
    this.title = true,
    this.lyrics = true,
    this.musicalNotes = true,
    this.rhythm = true,
    this.scale = true,
    this.tempo = true,
    this.chords = true,
    this.notes = true,
    this.quarterTones = true,
    this.tag = true,
  });

  final bool title;
  final bool lyrics;
  final bool musicalNotes;
  final bool rhythm;
  final bool scale;
  final bool tempo;
  final bool chords;
  final bool notes;
  final bool quarterTones;
  final bool tag;

  SongExportOptions copyWith({
    bool? title,
    bool? lyrics,
    bool? musicalNotes,
    bool? rhythm,
    bool? scale,
    bool? tempo,
    bool? chords,
    bool? notes,
    bool? quarterTones,
    bool? tag,
  }) {
    return SongExportOptions(
      title: title ?? this.title,
      lyrics: lyrics ?? this.lyrics,
      musicalNotes: musicalNotes ?? this.musicalNotes,
      rhythm: rhythm ?? this.rhythm,
      scale: scale ?? this.scale,
      tempo: tempo ?? this.tempo,
      chords: chords ?? this.chords,
      notes: notes ?? this.notes,
      quarterTones: quarterTones ?? this.quarterTones,
      tag: tag ?? this.tag,
    );
  }
}

class SongExportService {
  static const _fontAsset = 'assets/fonts/DejaVuSans.ttf';
  static const _boldFontAsset = 'assets/fonts/DejaVuSans-Bold.ttf';

  Future<String?> exportPdf({
    required List<Song> songs,
    required SongExportOptions options,
  }) async {
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final bytes = await _buildPdf(songs, options);
    return FilePicker.saveFile(
      dialogTitle: 'Export songs',
      fileName: 'melodiox_songs_$timestamp.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: Uint8List.fromList(bytes),
    );
  }

  Future<List<int>> _buildPdf(
    List<Song> songs,
    SongExportOptions options,
  ) async {
    final fonts = await _loadFonts();
    final document = pw.Document();
    final columns = _columns(options);
    final headers = [for (final column in columns) column.label];
    final data = <List<String>>[
      for (final song in songs)
        [for (final column in columns) column.value(song)],
    ];
    final cellStyle = pw.TextStyle(
      font: fonts.regular,
      fontFallback: [fonts.regular],
      fontSize: 8,
    );
    final headerStyle = pw.TextStyle(
      font: fonts.bold,
      fontFallback: [fonts.regular],
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            headerStyle: headerStyle,
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            cellAlignment: pw.Alignment.topLeft,
            cellStyle: cellStyle,
            headerDirection: pw.TextDirection.ltr,
            headerAlignments: {
              for (var index = 0; index < columns.length; index++)
                index: pw.Alignment.topLeft,
            },
            cellBuilder: (columnIndex, cell, rowIndex) {
              final value = cell.toString();
              final direction = _textDirectionFor(value);
              return pw.Text(
                value,
                style: cellStyle,
                textDirection: direction,
                textAlign: direction == pw.TextDirection.rtl
                    ? pw.TextAlign.right
                    : pw.TextAlign.left,
              );
            },
          ),
        ],
      ),
    );

    return document.save();
  }

  List<_ExportColumn> _columns(SongExportOptions options) {
    final columns = <_ExportColumn>[
      if (options.title) _ExportColumn('Title', (song) => song.name),
      if (options.tag)
        _ExportColumn(
          'Tags',
          (song) => song.tags.map((tag) => tag.name).join(', '),
        ),
      if (options.musicalNotes)
        _ExportColumn('Musical notes', (song) {
          final parts = [
            'My key: ${song.myStartingKey}',
            'Transpose: ${_formatSignedInt(song.transposeValue)}',
            if (song.originalStartingKey != null)
              'Original key: ${song.originalStartingKey}',
          ];
          return parts.join('\n');
        }),
      if (options.scale)
        _ExportColumn('Scale', (song) {
          final parts = [
            if (song.originalScale != null) 'Original: ${song.originalScale}',
            if (song.myScale != null) 'Mine: ${song.myScale}',
          ];
          return parts.join('\n');
        }),
      if (options.rhythm)
        _ExportColumn('Rhythm', (song) => song.allRhythmsSummary),
      if (options.tempo)
        _ExportColumn('Tempo', (song) => song.bpm == null ? '' : '${song.bpm}'),
      if (options.quarterTones)
        _ExportColumn('Quarter-toned keys', (song) => song.quarterToneSummary),
      if (options.chords)
        _ExportColumn('Chords', (song) {
          final chordImages =
              song.chordImages.map((media) => media.title).join(', ');
          return [
            if (song.linkedChordSummary.isNotEmpty) song.linkedChordSummary,
            if (chordImages.isNotEmpty) 'Images: $chordImages',
          ].join('\n');
        }),
      if (options.lyrics)
        _ExportColumn('Lyrics', (song) => song.lyrics?.trim() ?? ''),
      if (options.notes) _ExportColumn('Notes', (song) => song.notesSummary),
    ];
    if (columns.isEmpty) {
      return [_ExportColumn('Title', (song) => song.name)];
    }
    return columns;
  }

  Future<_PdfFonts> _loadFonts() async {
    final regularData = await rootBundle.load(_fontAsset);
    final boldData = await rootBundle.load(_boldFontAsset);
    return _PdfFonts(
      regular: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
    );
  }

  pw.TextDirection _textDirectionFor(String value) {
    return _containsArabic(value) ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  }

  bool _containsArabic(String value) {
    for (final rune in value.runes) {
      if ((rune >= 0x0600 && rune <= 0x06FF) ||
          (rune >= 0x0750 && rune <= 0x077F) ||
          (rune >= 0x08A0 && rune <= 0x08FF) ||
          (rune >= 0xFB50 && rune <= 0xFDFF) ||
          (rune >= 0xFE70 && rune <= 0xFEFF)) {
        return true;
      }
    }
    return false;
  }
}

String _formatSignedInt(int value) {
  return value >= 0 ? '+$value' : value.toString();
}

class _PdfFonts {
  const _PdfFonts({required this.regular, required this.bold});

  final pw.Font regular;
  final pw.Font bold;
}

class _ExportColumn {
  const _ExportColumn(this.label, this.value);

  final String label;
  final String Function(Song song) value;
}
