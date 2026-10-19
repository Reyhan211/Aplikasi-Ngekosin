/// Kota/area populer di Beranda ("Area Kos Populer").
class Area {
  final int id;
  final String name;
  final String? imagePath; // aset lokal ("assets/cities/x.jpg") atau URL/path dari API
  final int kosCount;

  const Area({
    required this.id,
    required this.name,
    this.imagePath,
    this.kosCount = 0,
  });

  factory Area.fromJson(Map<String, dynamic> j) => Area(
        id: int.parse(j['id'].toString()),
        name: (j['name'] ?? '').toString(),
        imagePath: j['image_url']?.toString(),
        kosCount: int.tryParse('${j['kos_count']}') ?? 0,
      );
}
