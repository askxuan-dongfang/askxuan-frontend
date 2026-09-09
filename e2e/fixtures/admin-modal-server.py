from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlparse
import json,base64,time
ROOT=Path(__file__).resolve().parents[2] / 'apps'
APPS={'admin':'web-platform-admin','shop':'web-shop-admin','temple':'web-temple-admin'}
coupon={'id':9,'name':'本地验收券','couponNo':'LOCAL9','type':'full_reduce','value':10,'minAmount':100,'totalCount':100,'receivedCount':1,'startTime':'2026-01-01 00:00:00','endTime':'2026-12-31 23:59:59','status':'enabled'}
def enc(v):return base64.urlsafe_b64encode(json.dumps(v).encode()).decode().rstrip('=')
class H(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
 def send(self,data,code=0):
  b=json.dumps({'code':code,'message':'local UI fixture','data':data},ensure_ascii=False).encode();self.send_response(200);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(b)));self.end_headers();self.wfile.write(b)
 def do_GET(self):
  p=urlparse(self.path).path
  if p.startswith('/api/'):
   data={'list':[],'items':[],'total':0,'permissions':[],'roles':[]}
   if p.endswith('/products/categories'):data={'list':[{'id':9,'name':'本地验收分类','parentId':0,'level':1,'sort':1}],'total':1}
   elif p.endswith('/temples/images'):data={'list':[{'id':9,'type':'detail','sort':1,'url':'data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22100%22 height=%22100%22/%3E'}]}
   elif p.endswith('/marketing/coupons'):data={'list':[coupon],'total':1}
   elif '/reports' in p or p.endswith('/report'):data={**data,'totalSales':0,'totalOrders':0,'avgOrderValue':0,'refundRate':0,'salesTrend':[],'topProducts':[],'revenueStats':{},'bookingTrend':[],'serviceDistribution':[],'masterRanking':[]}
   return self.send(data)
  seg=p.strip('/').split('/',1);app=APPS.get(seg[0]);
  if not app:return self.send_error(404)
  root=ROOT/app/'dist'; f=root/(seg[1] if len(seg)>1 else 'index.html')
  if not f.is_file():f=root/'index.html'
  b=f.read_bytes();self.send_response(200);self.send_header('Content-Type',self.guess_type(str(f)));self.send_header('Content-Length',str(len(b)));self.end_headers();self.wfile.write(b)
 def do_POST(self):
  d=json.loads(self.rfile.read(int(self.headers.get('Content-Length',0))) or b'{}')
  if self.path.endswith('/auth/admin/login'):
   key='shop' if 'shop' in d.get('account','') else 'temple' if 'temple' in d.get('account','') else 'platform'
   role={'shop':'shop_admin','temple':'temple_admin','platform':'platform_super'}[key]
   tok=enc({'alg':'none'})+'.'+enc({'userId':9901,'roles':[role],'clientId':key+'-admin','exp':int(time.time())+3600})+'.local-fixture'
   return self.send({'accessToken':tok,'refreshToken':'local-fixture','userInfo':{'userId':9901,'nickname':'本地验收账号','templeId':'TEST','templeName':'本地测试寺院','shopId':1}})
  self.send({},40303)
 def do_PUT(self):
  d=json.loads(self.rfile.read(int(self.headers.get('Content-Length',0))) or b'{}')
  if self.path.endswith('/coupons/9'):coupon.update(d);return self.send({'id':9})
  self.send({},40303)
 def do_DELETE(self):self.send({},40303)
ThreadingHTTPServer.request_queue_size=128
ThreadingHTTPServer(('127.0.0.1',5388),H).serve_forever()
