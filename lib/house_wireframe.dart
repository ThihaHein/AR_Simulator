// lib/engine/house_wireframe.dart
import 'dart:math';
import 'wireframe_model.dart';

class HouseWireframe {
  static WireframeModel generate() {
    final v = <Vec3>[];
    final e = <List<int>>[];
    const W=300.0,D=250.0,fH=120.0,gY=150.0;
    // FOUNDATION
    _box(v,e,0,gY+10,0,W/2+10,10,D/2+10);
    for(var fx=-W/2;fx<=W/2;fx+=40)_ln(v,e,Vec3(fx,gY+20,-D/2),Vec3(fx,gY+20,D/2));
    for(var fz=-D/2;fz<=D/2;fz+=40)_ln(v,e,Vec3(-W/2,gY+20,fz),Vec3(W/2,gY+20,fz));
    // F1 WALLS
    final f1y0=gY,f1y1=gY-fH;
    _wall(v,e,-W/2,f1y0,-D/2,W/2,f1y1,-D/2);_wall(v,e,-W/2,f1y0,D/2,W/2,f1y1,D/2);
    _wall(v,e,-W/2,f1y0,-D/2,-W/2,f1y1,D/2);_wall(v,e,W/2,f1y0,-D/2,W/2,f1y1,D/2);
    // F1 WINDOWS
    for(var i=0;i<3;i++)_win(v,e,-100.0+i*100,f1y0-35,-D/2-2,30,40,true);
    _win(v,e,-W/2-2,f1y0-40,-60,35,45,false);_win(v,e,-W/2-2,f1y0-40,60,35,45,false);
    _win(v,e,W/2+2,f1y0-40,-60,35,45,false);_win(v,e,W/2+2,f1y0-40,60,35,45,false);
    _win(v,e,-70,f1y0-35,D/2+2,30,40,true);_win(v,e,70,f1y0-35,D/2+2,30,40,true);
    // FRONT DOOR + PORCH
    _door(v,e,0,f1y0,-D/2-2,25,80,true);
    _box(v,e,0,f1y1+10,-D/2-30,40,3,25);
    _ln(v,e,Vec3(-35,f1y0,-D/2-50),Vec3(-35,f1y1+10,-D/2-50));
    _ln(v,e,Vec3(35,f1y0,-D/2-50),Vec3(35,f1y1+10,-D/2-50));
    for(var s=0;s<3;s++)_box(v,e,0,f1y0+s*8,-D/2-35-s*10.0,30,3,8);
    _door(v,e,0,f1y0,D/2+2,22,75,true);
    // F1 INTERIOR
    _iwall(v,e,-20,f1y0,-D/2+5,-20,f1y1+5,D/2-5);_iwall(v,e,20,f1y0,-D/2+5,20,f1y1+5,D/2-5);
    _iwall(v,e,-W/2+5,f1y0,-20,-25,f1y1+5,-20);_iwall(v,e,25,f1y0,-20,W/2-5,f1y1+5,-20);
    _iwall(v,e,-W/2+5,f1y0,40,-25,f1y1+5,40);
    _iwall(v,e,25,f1y0,60,W/2-5,f1y1+5,60);_iwall(v,e,80,f1y0,60,80,f1y1+5,D/2-5);
    _door(v,e,-25,f1y0,-20,18,70,true);_door(v,e,25,f1y0,-20,18,70,true);_door(v,e,80,f1y0,60,18,70,false);
    // LIVING ROOM
    _box(v,e,-100,f1y0-20,-80,45,18,15);_box(v,e,-100,f1y0-40,-80,45,5,12);
    _box(v,e,-55,f1y0-20,-80,3,18,15);_box(v,e,-145,f1y0-20,-80,3,18,15);
    _table(v,e,-100,f1y0,-45,30,15,20);
    _box(v,e,-100,f1y0-8,-D/2+15,35,8,12);_box(v,e,-100,f1y0-45,-D/2+15,30,25,2);
    _bookshelf(v,e,-W/2+12,f1y0,-80,10,90,30);_floorRect(v,e,-100,f1y0-1,-60,50,35);
    _lamp(v,e,-55,f1y0,-100);
    // KITCHEN
    _box(v,e,W/2-15,f1y0-35,-80,12,35,50);_box(v,e,80,f1y0-35,-D/2+15,45,35,12);
    _box(v,e,W/2-15,f1y0-36,-60,8,3,10);_box(v,e,60,f1y0-36,-D/2+15,15,3,10);
    for(var i=0;i<4;i++)_circXZ(v,e,52.0+(i%2)*16,f1y0-39,-D/2+10.0+(i~/2)*12,4,8);
    _box(v,e,W/2-15,f1y0-55,-D/2+15,14,55,14);
    _table(v,e,70,f1y0,-50,25,35,18);
    for(var i=0;i<3;i++)_stool(v,e,50+i*20.0,f1y0,-50);
    // DINING
    _table(v,e,-100,f1y0,80,40,30,25);
    for(var i=0;i<3;i++){_chair(v,e,-130,f1y0,60.0+i*20,1);_chair(v,e,-70,f1y0,60.0+i*20,-1);}
    _box(v,e,-W/2+12,f1y0-50,100,10,50,20);
    for(var i=0;i<4;i++)_floorRect(v,e,-W/2+12,f1y0-10-i*22.0,100,9,19);
    // F1 BATHROOM
    _box(v,e,W/2-20,f1y0-15,D/2-20,8,15,10);_box(v,e,W/2-20,f1y0-28,D/2-25,6,8,5);
    _box(v,e,100,f1y0-32,D/2-15,10,3,8);_ln(v,e,Vec3(100,f1y0-35,D/2-15),Vec3(100,f1y0-50,D/2-15));
    _box(v,e,100,f1y0-65,D/2-6,12,18,1);
    _box(v,e,W/2-20,f1y0-1,75,20,1,20);
    // CEILING
    _floorPlane(v,e,0,f1y1,0,W/2,D/2,60);
    // F2 WALLS
    final f2y0=f1y1,f2y1=f1y1-fH;
    _wall(v,e,-W/2,f2y0,-D/2,W/2,f2y1,-D/2);_wall(v,e,-W/2,f2y0,D/2,W/2,f2y1,D/2);
    _wall(v,e,-W/2,f2y0,-D/2,-W/2,f2y1,D/2);_wall(v,e,W/2,f2y0,-D/2,W/2,f2y1,D/2);
    for(var i=0;i<3;i++)_win(v,e,-100.0+i*100,f2y0-35,-D/2-2,28,38,true);
    _win(v,e,-W/2-2,f2y0-40,0,30,40,false);_win(v,e,W/2+2,f2y0-40,0,30,40,false);
    _win(v,e,-60,f2y0-35,D/2+2,28,38,true);_win(v,e,60,f2y0-35,D/2+2,28,38,true);
    // F2 INTERIOR
    _iwall(v,e,0,f2y0,-D/2+5,0,f2y1+5,D/2-5);
    _iwall(v,e,-W/2+5,f2y0,20,-5,f2y1+5,20);_iwall(v,e,5,f2y0,30,W/2-5,f2y1+5,30);
    _iwall(v,e,5,f2y0,D/2-50,W/2-5,f2y1+5,D/2-50);
    _door(v,e,-5,f2y0,20,18,70,true);_door(v,e,5,f2y0,30,18,70,true);_door(v,e,5,f2y0,D/2-50,18,70,true);
    // MASTER BEDROOM
    _box(v,e,-90,f2y0-15,-60,30,12,40);_box(v,e,-90,f2y0-30,-95,30,20,4);
    _box(v,e,-80,f2y0-17,-85,10,3,8);_box(v,e,-100,f2y0-17,-85,10,3,8);
    _box(v,e,-55,f2y0-18,-85,8,18,8);_box(v,e,-125,f2y0-18,-85,8,18,8);
    _box(v,e,-W/2+15,f2y0-30,0,12,30,25);
    for(var i=0;i<4;i++)_ln(v,e,Vec3(-W/2+3,f2y0-5.0-i*14,-25),Vec3(-W/2+3,f2y0-5.0-i*14,25));
    _box(v,e,-90,f2y0-50,D/2-15,35,50,12);_floorRect(v,e,-90,f2y0-1,-50,35,25);
    // KID ROOM
    _box(v,e,80,f2y0-12,-70,20,10,35);_box(v,e,80,f2y0-25,-100,20,15,4);
    _table(v,e,W/2-25,f2y0,-40,22,28,15);_chair(v,e,W/2-50,f2y0,-40,1);
    _bookshelf(v,e,W/2-12,f2y0,-90,10,70,20);_box(v,e,50,f2y0-12,-90,12,12,12);
    // F2 BATHROOM
    _box(v,e,W/2-25,f2y0-20,D/2-20,22,20,12);
    _box(v,e,30,f2y0-15,D/2-15,8,15,10);_box(v,e,30,f2y0-28,D/2-20,6,8,5);
    _box(v,e,55,f2y0-32,D/2-10,10,3,8);_box(v,e,55,f2y0-65,D/2-3,12,18,1);
    // STAIRS
    final sx=10.0,sz=0.0,steps=14,stepD=10.0,stepW=30.0,rise=fH/steps;
    for(var s=0;s<steps;s++){final sy=f1y0-s*rise;final ssz=sz-60+s*stepD;_box(v,e,sx,sy-rise/2,ssz,stepW/2,rise/2,stepD/2);}
    _ln(v,e,Vec3(sx-stepW/2,f1y0,sz-60),Vec3(sx-stepW/2,f2y0,sz-60+steps*stepD));
    _ln(v,e,Vec3(sx+stepW/2,f1y0,sz-60),Vec3(sx+stepW/2,f2y0,sz-60+steps*stepD));
    for(var b=0;b<steps;b+=2){final by=f1y0-b*rise;final bz=sz-60+b*stepD;
    _ln(v,e,Vec3(sx-stepW/2,by,bz),Vec3(sx-stepW/2,by-35,bz));
    _ln(v,e,Vec3(sx+stepW/2,by,bz),Vec3(sx+stepW/2,by-35,bz));}
    // ROOF
    final rY=f2y1,ridgeY=rY-80.0;
    _ln(v,e,Vec3(0,ridgeY,-D/2-15),Vec3(0,ridgeY,D/2+15));
    _ln(v,e,Vec3(-W/2-10,rY,-D/2-15),Vec3(0,ridgeY,-D/2-15));_ln(v,e,Vec3(W/2+10,rY,-D/2-15),Vec3(0,ridgeY,-D/2-15));
    _ln(v,e,Vec3(-W/2-10,rY,D/2+15),Vec3(0,ridgeY,D/2+15));_ln(v,e,Vec3(W/2+10,rY,D/2+15),Vec3(0,ridgeY,D/2+15));
    _ln(v,e,Vec3(-W/2-10,rY,-D/2-15),Vec3(-W/2-10,rY,D/2+15));_ln(v,e,Vec3(W/2+10,rY,-D/2-15),Vec3(W/2+10,rY,D/2+15));
    _ln(v,e,Vec3(-W/2-10,rY,-D/2-15),Vec3(W/2+10,rY,-D/2-15));_ln(v,e,Vec3(-W/2-10,rY,D/2+15),Vec3(W/2+10,rY,D/2+15));
    for(var rz=-D/2;rz<=D/2;rz+=30){_ln(v,e,Vec3(-W/2-10,rY,rz),Vec3(0,ridgeY,rz));_ln(v,e,Vec3(W/2+10,rY,rz),Vec3(0,ridgeY,rz));}
    _box(v,e,80,ridgeY-30,40,12,40,12);
    // DECK
    _box(v,e,0,f1y0+2,D/2+40,80,2,35);
    for(var dx=-75.0;dx<=75;dx+=12)_ln(v,e,Vec3(dx,f1y0,D/2+5),Vec3(dx,f1y0,D/2+75));
    _ln(v,e,Vec3(-80,f1y0,D/2+75),Vec3(80,f1y0,D/2+75));_ln(v,e,Vec3(-80,f1y0-35,D/2+75),Vec3(80,f1y0-35,D/2+75));
    for(var rx=-80.0;rx<=80;rx+=15)_ln(v,e,Vec3(rx,f1y0,D/2+75),Vec3(rx,f1y0-35,D/2+75));
    _table(v,e,-30,f1y0,D/2+45,18,12,18);_chair(v,e,-55,f1y0,D/2+45,1);_chair(v,e,-5,f1y0,D/2+45,-1);
    // GARAGE
    _box(v,e,W/2+60,f1y0-fH/2,-40,55,fH/2,50);_box(v,e,W/2+60,f1y0-40,-90,45,40,2);
    for(var i=0;i<4;i++)_ln(v,e,Vec3(W/2+15,f1y0-10.0-i*20,-92),Vec3(W/2+105,f1y0-10.0-i*20,-92));
    _box(v,e,W/2+60,f1y0-12,-30,30,10,20);_box(v,e,W/2+55,f1y0-28,-20,18,12,16);
    return WireframeModel(vertices:v,edges:e,name:'HOUSE',icon:'🏠');
  }
  static void _box(List<Vec3> v,List<List<int>> e,double cx,double cy,double cz,double w,double h,double d){final i=v.length;v.addAll([Vec3(cx-w,cy-h,cz-d),Vec3(cx+w,cy-h,cz-d),Vec3(cx+w,cy+h,cz-d),Vec3(cx-w,cy+h,cz-d),Vec3(cx-w,cy-h,cz+d),Vec3(cx+w,cy-h,cz+d),Vec3(cx+w,cy+h,cz+d),Vec3(cx-w,cy+h,cz+d)]);e.addAll([[i,i+1],[i+1,i+2],[i+2,i+3],[i+3,i],[i+4,i+5],[i+5,i+6],[i+6,i+7],[i+7,i+4],[i,i+4],[i+1,i+5],[i+2,i+6],[i+3,i+7]]);}
  static void _ln(List<Vec3> v,List<List<int>> e,Vec3 a,Vec3 b){final i=v.length;v.addAll([a,b]);e.add([i,i+1]);}
  static void _wall(List<Vec3> v,List<List<int>> e,double x0,double y0,double z0,double x1,double y1,double z1){final i=v.length;v.addAll([Vec3(x0,y0,z0),Vec3(x1,y0,z1),Vec3(x1,y1,z1),Vec3(x0,y1,z0)]);e.addAll([[i,i+1],[i+1,i+2],[i+2,i+3],[i+3,i]]);}
  static void _iwall(List<Vec3> v,List<List<int>> e,double x0,double y0,double z0,double x1,double y1,double z1){final i=v.length;v.addAll([Vec3(x0,y0,z0),Vec3(x1,y0,z1),Vec3(x1,y1,z1),Vec3(x0,y1,z0)]);e.addAll([[i,i+1],[i+1,i+2],[i+2,i+3],[i+3,i],[i,i+2]]);}
  static void _win(List<Vec3> v,List<List<int>> e,double cx,double cy,double cz,double w,double h,bool zW){final i=v.length;if(zW){v.addAll([Vec3(cx-w,cy-h,cz),Vec3(cx+w,cy-h,cz),Vec3(cx+w,cy+h,cz),Vec3(cx-w,cy+h,cz),Vec3(cx,cy-h,cz),Vec3(cx,cy+h,cz),Vec3(cx-w,cy,cz),Vec3(cx+w,cy,cz)]);}else{v.addAll([Vec3(cx,cy-h,cz-w),Vec3(cx,cy-h,cz+w),Vec3(cx,cy+h,cz+w),Vec3(cx,cy+h,cz-w),Vec3(cx,cy-h,cz),Vec3(cx,cy+h,cz),Vec3(cx,cy,cz-w),Vec3(cx,cy,cz+w)]);}e.addAll([[i,i+1],[i+1,i+2],[i+2,i+3],[i+3,i],[i+4,i+5],[i+6,i+7]]);}
  static void _door(List<Vec3> v,List<List<int>> e,double cx,double y0,double cz,double w,double h,bool zW){final i=v.length;if(zW){v.addAll([Vec3(cx-w,y0,cz),Vec3(cx+w,y0,cz),Vec3(cx+w,y0-h,cz),Vec3(cx-w,y0-h,cz),Vec3(cx+w-5,y0-h/2,cz),Vec3(cx+w-3,y0-h/2,cz)]);}else{v.addAll([Vec3(cx,y0,cz-w),Vec3(cx,y0,cz+w),Vec3(cx,y0-h,cz+w),Vec3(cx,y0-h,cz-w),Vec3(cx,y0-h/2,cz+w-5),Vec3(cx,y0-h/2,cz+w-3)]);}e.addAll([[i,i+1],[i+1,i+2],[i+2,i+3],[i+3,i],[i+4,i+5]]);}
  static void _table(List<Vec3> v,List<List<int>> e,double cx,double y0,double cz,double w,double h,double d){_box(v,e,cx,y0-h,cz,w,2,d);for(final ox in[-(w-3.0),w-3.0])for(final oz in[-(d-3.0),d-3.0])_ln(v,e,Vec3(cx+ox,y0,cz+oz),Vec3(cx+ox,y0-h+2,cz+oz));}
  static void _chair(List<Vec3> v,List<List<int>> e,double cx,double y0,double cz,int f){_box(v,e,cx,y0-18,cz,8,2,8);_box(v,e,cx,y0-38,cz-8.0*f,8,18,1);for(final ox in[-6.0,6.0])for(final oz in[-6.0,6.0])_ln(v,e,Vec3(cx+ox,y0,cz+oz),Vec3(cx+ox,y0-16,cz+oz));}
  static void _stool(List<Vec3> v,List<List<int>> e,double cx,double y0,double cz){_circXZ(v,e,cx,y0-28,cz,6,8);_ln(v,e,Vec3(cx,y0,cz),Vec3(cx,y0-26,cz));for(var l=0;l<4;l++){final a=l/4*2*pi;_ln(v,e,Vec3(cx+cos(a)*5,y0,cz+sin(a)*5),Vec3(cx,y0-26,cz));}}
  static void _bookshelf(List<Vec3> v,List<List<int>> e,double cx,double y0,double cz,double w,double h,double d){_box(v,e,cx,y0-h/2,cz,w,h/2,d);final s=(h/22).floor();for(var i=1;i<s;i++)_floorRect(v,e,cx,y0-i*(h/s),cz,w-1,d-1);for(var i=0;i<s;i++){final sy0=y0-i*(h/s);final sy1=y0-(i+1)*(h/s);for(var bz=cz-d+4;bz<cz+d-4;bz+=5)_ln(v,e,Vec3(cx,sy0,bz),Vec3(cx,sy1+2,bz));}}
  static void _lamp(List<Vec3> v,List<List<int>> e,double cx,double y0,double cz){_circXZ(v,e,cx,y0-1,cz,6,8);_ln(v,e,Vec3(cx,y0,cz),Vec3(cx,y0-60,cz));_circXZ(v,e,cx,y0-55,cz,10,8);_circXZ(v,e,cx,y0-65,cz,5,8);}
  static void _circXZ(List<Vec3> v,List<List<int>> e,double cx,double cy,double cz,double r,int s){final b=v.length;for(var i=0;i<s;i++){final a=i/s*2*pi;v.add(Vec3(cx+cos(a)*r,cy,cz+sin(a)*r));}for(var i=0;i<s;i++)e.add([b+i,b+(i+1)%s]);}
  static void _floorRect(List<Vec3> v,List<List<int>> e,double cx,double cy,double cz,double w,double d){final i=v.length;v.addAll([Vec3(cx-w,cy,cz-d),Vec3(cx+w,cy,cz-d),Vec3(cx+w,cy,cz+d),Vec3(cx-w,cy,cz+d)]);e.addAll([[i,i+1],[i+1,i+2],[i+2,i+3],[i+3,i]]);}
  static void _floorPlane(List<Vec3> v,List<List<int>> e,double cx,double cy,double cz,double w,double d,double gs){_floorRect(v,e,cx,cy,cz,w,d);for(var gx=cx-w;gx<=cx+w;gx+=gs)_ln(v,e,Vec3(gx,cy,cz-d),Vec3(gx,cy,cz+d));for(var gz=cz-d;gz<=cz+d;gz+=gs)_ln(v,e,Vec3(cx-w,cy,gz),Vec3(cx+w,cy,gz));}
}