/// Kampus untuk "Kos Sekitar Kampus". Di database: tabel `landmarks` (type = 'kampus').
class Campus {
  final int id;
  final String shortName; // "UGM"
  final String name;      // "Universitas Gadjah Mada"
  final String city;      // label lokasi, mis. "Jogja", "Depok"

  const Campus({
    required this.id,
    required this.shortName,
    required this.name,
    required this.city,
  });

  factory Campus.fromJson(Map<String, dynamic> j) => Campus(
        id: int.parse(j['id'].toString()),
        shortName: (j['short_name'] ?? j['name'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        city: (j['city'] ?? '').toString(),
      );
}
