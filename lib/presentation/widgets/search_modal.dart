import 'package:flutter/material.dart';

class SearchModal extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final List<Map<String, dynamic>> results;
  final VoidCallback onClose;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final ValueChanged<String> onChanged;

  const SearchModal({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.results,
    required this.onClose,
    required this.onSelect,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 60, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Ciudad, colonia, calle...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    onChanged: onChanged,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            )
          else if (results.isEmpty && controller.text.length >= 3)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Sin resultados', style: TextStyle(color: Colors.grey)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final place = results[i];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined, color: Colors.blue),
                  title: Text(
                    place['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    place['full_name'] as String,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onSelect(place),
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
