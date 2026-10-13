"""Local planner + bounded WCL read adapter; credentials stay in the existing CLI session."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import argparse
import json
import re
import shutil
import subprocess
import threading

ROOT=Path(__file__).resolve().parents[1]
WCL_LOCK=threading.Lock()
NODE=shutil.which('node')
def read_wcl(opts):
    if not isinstance(opts,dict): raise ValueError('请求无效')
    boss=opts.get('boss')
    if isinstance(boss,bool) or not isinstance(boss,int) or not 1<=boss<=1000000: raise ValueError('首领编号无效')
    mode=opts.get('mode')
    args=[NODE,str(ROOT/'tools/wcl_note.mjs'),mode]
    if mode=='report':
        report=opts.get('report','')
        hit=re.search(r'(?:https://(?:www\.)?warcraftlogs\.com/reports/)?([A-Za-z0-9]{8,32})(?:[?#].*)?$',report)
        fight,player=opts.get('fight'),opts.get('player','')
        if not hit or not isinstance(fight,int) or not 1<=fight<=10000 or not isinstance(player,str) or not re.fullmatch(r'[\w-]{1,80}',player): raise ValueError('请填写报告、战斗编号和玩家名字')
        args.extend([hit[1],'--fight',str(fight),'--player',player])
    elif mode=='top':
        cls,spec=opts.get('className',''),opts.get('specName','')
        if not re.fullmatch(r'[A-Za-z]{1,30}',cls) or not re.fullmatch(r'[A-Za-z]{1,30}',spec): raise ValueError('专精无效')
        rank=opts.get('rank',1)
        if not isinstance(rank,int) or not 1<=rank<=20: raise ValueError('记录序号须为1～20')
        args.extend(['--class',cls,'--spec',spec,'--rank',str(rank)])
        dungeon=opts.get('dungeon','')
        if dungeon:
            if not isinstance(dungeon,str) or not re.fullmatch(r'[A-Za-z0-9 \x27-]{1,80}',dungeon): raise ValueError('副本须为英文名或WCL排行编号')
            args.extend(['--dungeon',dungeon])
        else:
            difficulty=opts.get('difficulty',5)
            if difficulty not in (3,4,5): raise ValueError('难度无效')
            args.extend(['--difficulty',str(difficulty)])
            rank_id=opts.get('rankingID')
            if rank_id:
                if not isinstance(rank_id,int) or not 1<=rank_id<=1000000: raise ValueError('WCL排行编号无效')
                args.extend(['--ranking-id',str(rank_id)])
    else: raise ValueError('读取模式无效')
    args.extend(['--boss',str(boss)])
    spells=opts.get('spells','')
    if spells:
        if not isinstance(spells,str) or not re.fullmatch(r'\d{1,8}(?:,\d{1,8}){0,99}',spells): raise ValueError('技能编号用英文逗号分隔')
        args.extend(['--spells',spells])
    if not WCL_LOCK.acquire(blocking=False): raise ValueError('已有一个WCL请求，请稍后重试')
    try:
        r=subprocess.run(args,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',timeout=90,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
    finally: WCL_LOCK.release()
    if r.returncode:
        # Raw upstream output may contain diagnostics. Do not return it to a browser.
        raise ValueError('未能读取记录：请检查本机WCL配置、首领/副本编号、报告权限或是否有带日志的排行。')
    if len(r.stdout.encode('utf-8'))>200000: raise ValueError('导出记录过大，请缩小技能范围')
    return {'note':r.stdout}

class Handler(SimpleHTTPRequestHandler):
    extensions_map={**SimpleHTTPRequestHandler.extensions_map,'.mjs':'text/javascript','.css':'text/css','.webp':'image/webp','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.svg':'image/svg+xml'}
    def __init__(self,*args,**kwargs): super().__init__(*args,directory=str(ROOT/'web'),**kwargs)
    def log_message(self,*args): pass
    def end_headers(self):
        self.send_header('X-Content-Type-Options','nosniff')
        self.send_header('Cache-Control','no-store')
        super().end_headers()
    def do_POST(self):
        if self.path!='/api/wcl': self.send_error(404); return
        if self.headers.get('Host') not in (f'127.0.0.1:{self.server.server_port}',f'localhost:{self.server.server_port}'):
            self.send_error(403); return
        origin=self.headers.get('Origin')
        if origin and origin!=f'http://{self.headers.get("Host")}': self.send_error(403); return
        try:
            length=int(self.headers.get('Content-Length',0))
            if not 1<=length<=10000: raise ValueError('请求过大或为空')
            if not NODE: raise ValueError('本机未找到Node.js')
            body=read_wcl(json.loads(self.rfile.read(length))); code=200
        except (ValueError,TypeError,subprocess.TimeoutExpired,OSError):
            body={'error':'WCL读取未完成，请检查输入、本机配置或稍后重试。'}; code=400
        data=json.dumps(body,ensure_ascii=False).encode('utf-8')
        self.send_response(code); self.send_header('Content-Type','application/json; charset=utf-8');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=0);args=parser.parse_args()
    server=ThreadingHTTPServer(('127.0.0.1',args.port),Handler)
    print(f'Local: http://127.0.0.1:{server.server_port}/',flush=True)
    server.serve_forever()
