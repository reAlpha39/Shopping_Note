import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:datetime_picker_formfield/datetime_picker_formfield.dart';
import 'package:shoping_note/models/belanja_harian.dart';
import 'package:shoping_note/models/item_belanja.dart';

class FormPage extends StatefulWidget {

  final String title;
  final String tanggal;
  final String docID;

  const FormPage({this.title, this.tanggal, this.docID});
  @override
  _FormPageState createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController namaC = TextEditingController();
  TextEditingController deskC = TextEditingController();
  TextEditingController hargaC = TextEditingController();
  TextEditingController tanggalC = TextEditingController();
  final dateFormat = DateFormat('yyyy-MM-dd');
  DateTime date;
  String _tanggal;
  String _nama;
  String _deskripsi;
  int _harga;
  int jumUang = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: SingleChildScrollView(
            child: Form(
            key: _formKey,
            child: Column(children: <Widget>[
              DateTimeField(
                controller: tanggalC,
                decoration: InputDecoration(
                  labelText: 'Tanggal'
                ),
                readOnly: true,
                format: dateFormat,
                initialValue: DateTime.now(),
                onShowPicker: (context, currentValue) {
                  return showDatePicker(
                    context: context,
                    firstDate: DateTime(1900),
                    initialDate: currentValue ?? DateTime.now(),
                    lastDate: DateTime(2100)
                  );
                },
                onSaved: (value) {_tanggal = dateFormat.format(value);},
              ),
              TextFormField(
                controller: namaC,
                decoration: InputDecoration(
                  labelText: 'Nama'
                ),
                validator: (i) {
                  if (i == ''){
                    return 'Nama harus diisi';
                  }else{
                    return null;
                  }
                },
                onSaved: (value) {_nama = value;},
              ),
              TextFormField(
                maxLines: 3,
                controller: deskC,
                decoration: InputDecoration(
                  labelText: 'Deskripsi'
                ),
                onSaved: (value) {_deskripsi = value;},
              ),
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Total Belanja'
                ),
                onSaved: (value) {_harga = int.parse(value);},
                validator: (i) {
                  if (i == '') {
                    return 'Total Belanja harus diisi';
                  }
                  if (int.tryParse(i) == null) {
                    return 'Total Belanja harus berupa angka';
                  } else {
                    return null;
                  }
                },
                controller: hargaC,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                  RaisedButton(
                    child: Text('Cancel'),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  RaisedButton(
                    child: Text('Save'),
                    onPressed: () {
                      var form = _formKey.currentState;
                      if (form.validate()) {
                        form.save();
                        saveData(_tanggal, _nama, _deskripsi, _harga);
                        Navigator.pop(context);
                      }
                    },
                  )
                ],),
              )
            ]),
          ),
        ),
      ),
      
    );
  }

  void saveData(String doc, String nama, String desk, int harga) async {

    ItemBelanja itemBelanja = ItemBelanja(
      nama: nama,
      deskripsi: desk,
      harga: harga
    );
    var dbItem = Firestore.instance.collection('Daftar Belanja').document(doc).collection(doc);
    if(widget.docID ==  null){
      //Save data
      await dbItem.document(nama).setData(itemBelanja.toMap());
    }else{
      if(doc == widget.tanggal){
        //Edit data item dengan tanggal yang sama
        await dbItem.document(widget.docID).updateData(itemBelanja.toMap());
      }else{
        //Edit data item dengan tanggal yang berbeda
        await dbItem.document(widget.docID).setData(itemBelanja.toMap());
        var dbOld = Firestore.instance.collection('Daftar Belanja').document(widget.tanggal)
        .collection(widget.tanggal);
        await dbOld.document(widget.docID).delete();
        var dataOld = await dbOld.getDocuments();
        var jumDocOld = dataOld.documents.length;
        if(jumDocOld == 0){
          // jika tidak ada data dalam tanggal setelah data pindah
          await Firestore.instance.collection('Daftar Belanja').document(widget.tanggal).delete();
        }else{
          //jika ada dalam tanggal setelah data dipindah
          updateDocHarian(dbOld, widget.tanggal);
        }
      }
    }
    updateDocHarian(dbItem, doc);
  }

  updateDocHarian(CollectionReference collectionReference, String doc) async {
    var dataItem = await collectionReference.getDocuments();
    var docTanggal = Firestore.instance.collection('Daftar Belanja').document(doc);
    var dataTanggal = await docTanggal.get();
    int jumItem = dataItem.documents.length;
    BelanjaHarian belanjaHarian = BelanjaHarian(
      tanggal: DateTime.parse(doc),
      jumlahDoc: jumItem,
      totalPengeluaran: counterPengeluaran(dataItem)
    );
    if(dataTanggal.exists){
      await docTanggal.updateData(belanjaHarian.toMap());
    }else{
      await docTanggal.setData(belanjaHarian.toMap());
    }
  }

  int counterPengeluaran(QuerySnapshot querySnapshot){
    int jumItem = querySnapshot.documents.length;
    int jumlahUang = 0;
    int index = 0;
    do {
      var data = ItemBelanja.fromMap(querySnapshot.documents[index].data);
      var uang = data.harga;
      jumlahUang = jumlahUang + uang;
      index++;
    } while (index < jumItem);
    return jumlahUang;
  }

  void initState(){
    if(widget.docID != null){
      dataAwal();
      super.initState();
    }else{
      tanggalC.text = dateFormat.format(DateTime.now());
    }
  }

  void dataAwal() async {
    var db = Firestore.instance.collection('Daftar Belanja')
      .document(widget.tanggal).collection(widget.tanggal).document(widget.docID);
    var data = await db.get();
    var dataItem = ItemBelanja.fromMap(data.data);
    namaC.text = dataItem.nama;
    deskC.text = dataItem.deskripsi;
    hargaC.text = dataItem.harga.toString();
    tanggalC.text = widget.tanggal;
  }
}