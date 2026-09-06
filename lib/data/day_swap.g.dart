import 'package:hive/hive.dart';
import 'day_swap.dart';

class DaySwapAdapter extends TypeAdapter<DaySwap> {
  @override final int typeId = 8;
  @override DaySwap read(BinaryReader r) => DaySwap(id: r.read(), targetDate: r.read(), sourceDate: r.read());
  @override void write(BinaryWriter w, DaySwap o) { w..write(o.id)..write(o.targetDate)..write(o.sourceDate); }
}
