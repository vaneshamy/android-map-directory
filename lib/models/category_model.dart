class CategoryModel {
  final String id;
  final String name;
  final String? icon; 
  final String? slug; 

  CategoryModel({required this.id, required this.name, this.icon, this.slug});

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'].toString(),
      name: json['name'] ?? 'Tanpa Nama', 
      icon: json['icon']?.toString(),   
      slug: json['slug']?.toString(),  
    );
  }
}