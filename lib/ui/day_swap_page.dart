import 'package:flutter/cupertino.dart';
import '../data/day_swap.dart';
import '../data/storage.dart';

class DaySwapPage extends StatefulWidget { const DaySwapPage({super.key}); @override State<DaySwapPage> createState()=>_DaySwapPageState(); }
class _DaySwapPageState extends State<DaySwapPage> {
  DateTime _target=DateTime.now(), _source=DateTime.now();
  Future<void> _add() async { final d=DateTime(_target.year,_target.month,_target.day); final s=DateTime(_source.year,_source.month,_source.day); final id=d.toIso8601String(); await AppStorage.daySwaps.put(id,DaySwap(id:id,targetDate:d,sourceDate:s)); if(mounted)setState((){}); }
  @override Widget build(BuildContext c)=>CupertinoPageScaffold(navigationBar:const CupertinoNavigationBar(middle:Text('整天调课')),child:SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[_pick(c,true),_pick(c,false),CupertinoButton.filled(onPressed:_add,child:const Text('保存调课')),const SizedBox(height:20),for(final s in AppStorage.daySwaps.values)CupertinoListTile(title:Text('${s.targetDate.year}-${s.targetDate.month}-${s.targetDate.day} 按 ${s.sourceDate.year}-${s.sourceDate.month}-${s.sourceDate.day} 上课'),trailing:CupertinoButton(padding:EdgeInsets.zero,onPressed:(){s.delete();setState((){});},child:const Text('撤销',style:TextStyle(color:CupertinoColors.systemRed))))])));
  Widget _pick(BuildContext c,bool target)=>CupertinoButton(onPressed:()async{var d=target?_target:_source;await showCupertinoModalPopup(context:c,builder:(_)=>SizedBox(height:280,child:CupertinoDatePicker(mode:CupertinoDatePickerMode.date,initialDateTime:d,onDateTimeChanged:(v)=>d=v)));if(mounted)setState(()=>target?_target=d:_source=d);},child:Text('${target?'目标':'来源'}日期：${(target?_target:_source).year}-${(target?_target:_source).month}-${(target?_target:_source).day}'));
}
