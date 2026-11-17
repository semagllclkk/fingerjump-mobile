import 'package:flutter/material.dart';
import 'package:pixel_game/game/accessories.dart';
import 'package:pixel_game/services/save_data.dart';
import 'package:pixel_game/ui/farm_theme.dart';

/// Coin'lerle kedilere şapka / aksesuar alınan dükkân.
///
/// Bir eşyaya dokununca kedinin üstünde önizlenir. Alt düğme duruma göre
/// SATIN AL → TAK → ÇIKAR olur. Satın alınan eşya hemen takılır.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late Accessory _selected =
      SaveData.current.value.equipped ?? Accessory.values.first;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SaveData>(
      valueListenable: SaveData.current,
      builder: (context, save, _) {
        final info = AccessoryInfo.of(_selected);
        final owned = save.owned.contains(_selected);
        final equipped = save.equipped == _selected;
        final canAfford = save.coins >= info.price;

        return Scaffold(
          body: FarmSkyBackground(
            child: SafeArea(
              child: Column(
                children: [
                  FarmTopBar(title: 'Dükkan'),
                  _CoinBadge(coins: save.coins),
                  AnimatedCat(
                    key: ValueKey(_selected),
                    breed: save.cat,
                    scale: 6,
                    accessory: _selected,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: VineCard(
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            Text(info.name, style: Farm.text(30, height: 1)),
                            Text(
                              info.text,
                              textAlign: TextAlign.center,
                              style: Farm.text(
                                20,
                                color: Farm.ink2,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final a in AccessoryInfo.all)
                            _ItemTile(
                              info: a,
                              save: save,
                              selected: a.id == _selected,
                              onTap: () => setState(() => _selected = a.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    child: _actionButton(
                      info,
                      owned: owned,
                      equipped: equipped,
                      canAfford: canAfford,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _actionButton(
    AccessoryInfo info, {
    required bool owned,
    required bool equipped,
    required bool canAfford,
  }) {
    if (equipped) {
      return WoodButton(
        label: 'ÇIKAR',
        color: Farm.wood,
        onPressed: () => _run(() => SaveData.equip(null)),
      );
    }
    if (owned) {
      return WoodButton(
        label: 'TAK',
        color: Farm.green,
        onPressed: () => _run(() => SaveData.equip(info.id)),
      );
    }
    return Opacity(
      opacity: canAfford ? 1 : 0.55,
      child: WoodButton(
        label: canAfford
            ? 'SATIN AL · ${info.price}'
            : '${info.price} coin gerekli',
        onPressed: canAfford ? () => _run(() => SaveData.buy(info.id)) : null,
      ),
    );
  }

  Future<void> _run(Future<Object?> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } finally {
      _busy = false;
    }
  }
}

class _CoinBadge extends StatelessWidget {
  final int coins;
  const _CoinBadge({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Farm.parch,
        border: Border.all(color: Farm.wood, width: 3),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Farm.woodDark, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SpinningCoin(scale: 2),
          const SizedBox(width: 6),
          Text('$coins', style: Farm.text(26)),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final AccessoryInfo info;
  final SaveData save;
  final bool selected;
  final VoidCallback onTap;

  const _ItemTile({
    required this.info,
    required this.save,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final owned = save.owned.contains(info.id);
    final equipped = save.equipped == info.id;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 104,
        height: 128,
        transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: selected ? Farm.parch : Farm.parch2,
          border: Border.all(
            color: selected ? Farm.pink : Farm.parch3,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: selected ? Farm.pink : Farm.parch3,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CatView(breed: save.cat, accessory: info.id, scale: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(info.name, style: Farm.text(17, height: 1)),
              ),
            ),
            if (equipped)
              Text('Takılı', style: Farm.text(17, color: Farm.pink, height: 1))
            else if (owned)
              Text('Senin', style: Farm.text(17, color: Farm.green, height: 1))
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SpinningCoin(scale: 1),
                  const SizedBox(width: 3),
                  Text(
                    '${info.price}',
                    style: Farm.text(17, color: Farm.ink2, height: 1),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
