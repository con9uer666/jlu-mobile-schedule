import 'package:flutter/cupertino.dart';
import '../data/day_swap.dart';
import '../data/storage.dart';

class DaySwapPage extends StatefulWidget { const DaySwapPage({super.key}); @override State<DaySwapPage> createState()=>_DaySwapPageState(); }
class _DaySwapPageState extends State<DaySwapPage> {
  DateTime _target=DateTime.now(); int _source=1;
  Future<void> _add() async { final d=DateTime(_target.year,_target.month,_target.day); final id='${d.toIso8601String()}'; await AppStorage.daySwaps.put(id,DaySwap(id:id,targetDate:d,sourceWeekday:_source)); if(mounted)setState((){}); }
  @override Widget build(BuildContext c)=>CupertinoPageScaffold(navigationBar:const CupertinoNavigationBar(middle:Text('整天调课')),child:SafeArea(child:ListView(padding:const EdgeInsets.all(16),children:[CupertinoButton(onPressed:()async{var d=_target;await showCupertinoModalPopup(context:c,builder:(_)=>SizedBox(height:280,child:CupertinoDatePicker(mode:CupertinoDatePickerMode.date,initialDateTime:d,onDateTimeChanged:(v)=>d=v)));if(mounted)setState(()=>_target=d);},child:Text('目标日期：${_target.year}-${_target.month}-${_target.day}')),CupertinoFormRow(prefix:const Text('按星期几上课'),child:CupertinoSlidingSegmentedControl<int>(groupValue:_source,children:const{1:Text('一'),2:Text('二'),3:Text('三'),4:Text('四'),5:Text('五'),6:Text('六'),7:Text('日')},onValueChanged:(v){if(v!=null)setState(()=>_source=v);})),CupertinoButton.filled(onPressed:_add,child:const Text('保存调课')),const SizedBox(height:20),for(final s in AppStorage.daySwaps.values)CupertinoListTile(title:Text('${s.targetDate.year}-${s.targetDate.month}-${s.targetDate.day} 按周${s.sourceWeekday}课程'),trailing:CupertinoButton(padding:EdgeInsets.zero,onPressed:(){s.delete();setState((){});},child:const Text('撤销',style:TextStyle(color:CupertinoColors.systemRed))))])));
}
