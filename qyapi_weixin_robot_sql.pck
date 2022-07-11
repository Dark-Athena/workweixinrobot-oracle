create or replace package qyapi_weixin_robot_sql  is
/*
Copyright DarkAthena(darkathena@qq.com)

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/
  -- Author  : DarkAthena
  -- Created : 2020-06-15 13:33:16
  -- Purpose : 企业微信群机器人API
  -- EMAIL :darkathena@qq.com
  
  g_WALLET_path varchar2(1000):='H:\ssl_wallet';--钱夹保存路径
  g_wallet_pwd varchar2(1000) :='password'; --钱夹密码，若设置了自动登录，可为空
  g_content_type varchar2(1000):='application/json';
  procedure sendmsg_text(i_webhook varchar2,i_content_text varchar2);--发送文本信息
  procedure sendmsg_file(i_webhook  varchar2,
                         i_dir      varchar2,
                         i_file_name varchar2,
                         i_display_file_name varchar2);--发送文件信息
  procedure sendmsg_image(i_webhook varchar2,i_dir varchar2,i_imagename varchar2);--发送图片信息
  function upload_media(i_webhook  varchar2,
                         I_db_Path      varchar2,
                         i_file_name         varchar2,
                         i_display_file_name varchar2)  return varchar2;--上传媒体文件
end qyapi_weixin_robot_sql ;
/
create or replace package body qyapi_weixin_robot_sql  is
  function replace_fun(pSourceStr in varchar2) return varchar2 is
  v_str varchar2(2000);
begin
  --数据中如果有json中的保留字符则替换掉
  v_str:=replace(pSourceStr,':','：');
  v_str:=replace(v_str,',','，');
  v_str:=replace(v_str,'{','｛');
  v_str:=replace(v_str,'}','｝');
  v_str:=replace(v_str,'[','【');
  v_str:=replace(v_str,']','】');
  v_str:=replace(v_str,'"','“');
  v_str:=replace(v_str,'\','∕');
  v_str:=replace(v_str,chr(10),'');
  v_str:=replace(v_str,chr(13),'');
  v_str:=replace(v_str,'-','');
  v_str:=replace(v_str,'&','＆');
  v_str:=replace(v_str,'%','﹪');
  return v_str;
end;
                 
    PROCEDURE to_base64(dest IN OUT NOCOPY CLOB, src in blob) IS
    --取 3 的倍數(UTF-8) 又因為需要按照64字符每行分行，所以需要是16的倍數，所以下面的長度必需為 48的倍數
    sizeB integer := 6144;
    buffer raw(6144);
    offset integer default 1;
  begin

    loop
       begin
       dbms_lob.read(src, sizeB, offset, buffer);
       exception
         when no_data_found then
           exit;
       end;
       offset := offset + sizeB;
       dbms_lob.append(dest, to_clob(utl_raw.cast_to_varchar2(utl_encode.base64_encode(buffer))));
    end loop;
  END to_base64;
  
  function file2blob(p_dir varchar2, p_file_name varchar2) return blob is
    file_lob  bfile;
    file_blob blob;
  begin
    file_lob := bfilename(p_dir, p_file_name);
    dbms_lob.open(file_lob, dbms_lob.file_readonly);
    dbms_lob.createtemporary(file_blob, true);
    dbms_lob.loadfromfile(file_blob, file_lob, dbms_lob.lobmaxsize);
    dbms_lob.close(file_lob);
    return file_blob;
  exception
    when others then
      if dbms_lob.isopen(file_lob) = 1 then
        dbms_lob.close(file_lob);
      end if;
      if dbms_lob.istemporary(file_blob) = 1 then
        dbms_lob.freetemporary(file_blob);
      end if;
      raise;
  end;
  
FUNCTION Clob2Blob(v_blob_in IN CLOB) RETURN BLOB IS

  v_file_clob    BLOB;
  v_file_size    INTEGER := dbms_lob.lobmaxsize;
  v_dest_offset  INTEGER := 1;
  v_src_offset   INTEGER := 1;
  v_blob_csid    NUMBER := dbms_lob.default_csid;
  v_lang_context NUMBER := dbms_lob.default_lang_ctx;
  v_warning      INTEGER;

BEGIN

  dbms_lob.createtemporary(v_file_clob, TRUE);

  dbms_lob.converttoBlob(v_file_clob,
                         v_blob_in,
                         v_file_size,
                         v_dest_offset,
                         v_src_offset,
                         v_blob_csid,
                         v_lang_context,
                         v_warning);

  RETURN v_file_clob;

EXCEPTION
  WHEN OTHERS THEN
    dbms_output.put_line('Error found');

END;

  procedure set_wallet is
    o_error_message varchar2(4000);
  begin
    UTL_HTTP.SET_WALLET('file:'||g_WALLET_path,g_wallet_pwd);
  exception
    when others then
      o_error_message := '**Error line: ' ||
                         dbms_utility.format_error_backtrace() || '-' ||
                         '**Error info: ' || SQLERRM;
      Raise_application_error(-20001, o_error_message);
  end;

  FUNCTION post(i_url VARCHAR2, i_post_data CLOB) RETURN VARCHAR2 is
    req               utl_http.req;
    resp              utl_http.resp;
    VALUE             VARCHAR2(4000);
    l_http_return_msg VARCHAR2(4000);
  
  BEGIN
    set_wallet;
    --   dbms_output.put_line(i_url);
  
    -- dbms_output.put_line(i_post_data);
    req := utl_http.begin_request(i_url, 'POST', 'HTTP/1.1');
    utl_http.set_header(req, 'Content-Type', g_content_type);
    --'application/x-www-form-urlencoded'
    --'application/json'
  
    utl_http.set_header(req,
                        'Content-Length',
                        dbms_lob.getlength(i_post_data));
  
    ---写入POST数据
    DECLARE
    
      sizeb  INTEGER := 1440;
      buffer VARCHAR2(1440);
      offset INTEGER DEFAULT 1;
    BEGIN
      LOOP
        BEGIN
          dbms_lob.read(i_post_data, sizeb, offset, buffer);
        
        EXCEPTION
          WHEN no_data_found THEN
          
            EXIT;
        END;
        offset := offset + sizeb;
        utl_http.write_text(req, buffer);
      END LOOP;
    END;
    ---获取返回值
    resp := utl_http.get_response(req);
    utl_http.read_raw(resp, VALUE, 2000);
    utl_http.end_response(resp);
    l_http_return_msg := utl_raw.cast_to_varchar2(VALUE);
    RETURN l_http_return_msg;
   EXCEPTION
    WHEN OTHERS THEN
      utl_http.close_persistent_conns;
      utl_tcp.close_all_connections;
      dbms_output.put_line('**Error line: ' ||
                           dbms_utility.format_error_backtrace() || '-' ||
                           '**Error info: ' || SQLERRM);
    --  RETURN '0';
    RAISE;
  end;

  FUNCTION post(i_url VARCHAR2, i_post_data BLOB) RETURN VARCHAR2 is
    req               utl_http.req;
    resp              utl_http.resp;
    VALUE             VARCHAR2(4000);
    l_http_return_msg VARCHAR2(4000);
  
  BEGIN
    --   dbms_output.put_line(i_url);
    set_wallet;
    -- dbms_output.put_line(i_post_data);
    req := utl_http.begin_request(i_url, 'POST', 'HTTP/1.1');
    utl_http.set_header(req, 'Content-Type', g_content_type);
    --'application/x-www-form-urlencoded'
    --'application/json'
  
    utl_http.set_header(req,
                        'Content-Length',
                        dbms_lob.getlength(i_post_data));
  
    ---写入POST数据
    DECLARE
    
      sizeb  INTEGER := 1440;
      buffer raw(1440);
      offset INTEGER DEFAULT 1;
    BEGIN
      LOOP
        BEGIN
          dbms_lob.read(i_post_data, sizeb, offset, buffer);
        
        EXCEPTION
          WHEN no_data_found THEN
          
            EXIT;
        END;
        offset := offset + sizeb;
        utl_http.write_raw(req, buffer);
      END LOOP;
    END;
    ---获取返回值
    resp := utl_http.get_response(req);
    utl_http.read_raw(resp, VALUE, 2000);
    utl_http.end_response(resp);
    l_http_return_msg := utl_raw.cast_to_varchar2(VALUE);
    RETURN l_http_return_msg;
  EXCEPTION
    WHEN OTHERS THEN
      utl_http.close_persistent_conns;
      utl_tcp.close_all_connections;
      dbms_output.put_line('**Error line: ' ||
                           dbms_utility.format_error_backtrace() || '-' ||
                           '**Error info: ' || SQLERRM);
      RETURN '0';
  END;
function upload_media(i_webhook  varchar2,
                         I_db_Path      varchar2,
                         i_file_name         varchar2,
                         i_display_file_name varchar2)  return varchar2 is
    url VARCHAR2(1000);
    o_error_message varchar2(4000);

    req   UTL_HTTP.REQ;
    resp  UTL_HTTP.RESP;
    value VARCHAR2(4000);
    BEGIN_TEXT VARCHAR2(4000);
    END_TEXT VARCHAR2(4000);

    BODY_blob         blob;
    l_HTTP_RETURN_MSG varchar2(4000);

    l_type       varchar2(20);
    l_return_msg varchar2(32000);
    L_BEGIN_TEXT varchar2(32000);
    l_filelength number;
     begin_raw raw(32767);
     end_raw raw(32767);
     l_return_json json;
     l_media_id varchar2(1000);
  BEGIN
        set_wallet;

    l_filelength := DBMS_LOB.GETLENGTH(BFILENAME(I_db_Path, i_file_name));
    DBMS_OUTPUT.put_line(l_filelength);
    IF l_filelength >= 20 * 1024 * 1024 THEN
      Raise_application_error(-20001, '文件超过20M,无法发送');
    END IF;
 
    l_type       := 'file';
    L_BEGIN_TEXT := 'type=' || l_type || chr(38) ||
                    'key=' || i_webhook 
                   
                    ;

    URL := 'https://qyapi.weixin.qq.com/cgi-bin/webhook/upload_media' || '?' || L_BEGIN_TEXT;

    dbms_output.put_line(URL);

    BODY_blob := file2blob(i_db_path, i_file_name);

    l_filelength := DBMS_LOB.getlength(BODY_blob);
    DBMS_OUTPUT.put_line(l_filelength);

    BEGIN_TEXT := q'{----------pS6m0U35MAZ7qdVl}' || chr(13) || chr(10) ||
                  q'{Content-Disposition: form-data; name="media"; filelength="l_filelength"; filename="i_file_name"}' ||
                  chr(13) || chr(10) ||
                  q'{Content-Type: application/octet-stream}' || chr(13) ||
                  chr(10) || chr(13) || chr(10);

    BEGIN_TEXT := replace(BEGIN_TEXT, 'i_file_name', /*convert(*/replace_fun(i_display_file_name)/*, 'AL32UTF8', 'ZHS16GBK')*/);
    BEGIN_TEXT := replace(BEGIN_TEXT, 'l_filelength', l_filelength);

    END_TEXT := chr(13) || chr(10) || Q'{----------pS6m0U35MAZ7qdVl--}' ||
                chr(13) || chr(10);
    -- LLL:=utl_url.escape(LLL,escape_reserved_chars => FALSE,url_charset => 'UTF-8');

  --  begin_text := rtrim(CONVERT(begin_text, 'ZHS16GBK', 'AL32UTF8'),chr(0));
  --  END_TEXT := rtrim(CONVERT(END_TEXT, 'ZHS16GBK', 'AL32UTF8'),chr(0));

  --  END_TEXT := CONVERT(END_TEXT, 'ZHS16GBK', 'AL32UTF8');

    begin_raw:=utl_raw.cast_to_raw(begin_text);
    end_raw:=utl_raw.cast_to_raw(end_text);

    DBMS_OUTPUT.put_line(BEGIN_TEXT);
    DBMS_OUTPUT.put_line(END_TEXT);

    ---开始POST 请求
    req := UTL_HTTP.BEGIN_REQUEST(URL, 'POST', 'HTTP/1.1');
    utl_http.set_header(req, 'Connection', 'Keep-Alive');
    utl_http.set_header(req,
                        'Content-Type',
                        'multipart/form-data;boundary=--------pS6m0U35MAZ7qdVl');
    --   utl_http.set_header(req, 'Accept-Encoding', '  gzip, deflate');
    --   utl_http.set_header(req, 'Accept-Language', '  zh-CN,zh;q=0.8');
  --  utl_http.set_header(req, 'Charset', 'UTF-8');
    utl_http.set_header(req,
                        'Content-Length',
                        LENGTHb(BEGIN_TEXT) + l_filelength +
                        LENGTHb(END_TEXT));

    /*  utl_http.set_header(req,
     'Content-Length',
    to_char( utl_raw.length (BEGIN_raw) + l_filelength +
     utl_raw.length (END_raw)));*/

    dbms_output.put_line('Content-Length:' ||
                         to_char(LENGTHb(BEGIN_TEXT) + l_filelength +
                                 LENGTHb(END_TEXT)));
    ---写入POST数据

  --  utl_http.write_text(req, BEGIN_TEXT);

      utl_http.write_raw(req,begin_raw);

    declare

      sizeB  integer := 1440;
      buffer RAW(1440);
      offset integer default 1;
    begin
      loop
        begin
          dbms_lob.read(BODY_blob, sizeB, offset, buffer);

        exception
          when no_data_found then

            exit;
        end;
        offset := offset + sizeB;
        utl_http.write_RAW(req, buffer);
      end loop;
    END;
    -- utl_http.write_text(req, 'dddddddddd');

--    utl_http.write_text(req, END_TEXT);
      utl_http.write_raw(req,END_raw);

    ---获取返回值
    resp := utl_http.get_response(req);
    utl_http.read_raw(resp, VALUE, 2000);
    utl_http.end_response(resp);
    -- DBMS_OUTPUT.put_line('---' || UTL_RAW.cast_to_varchar2(VALUE));

    l_HTTP_RETURN_MSG := CONVERT(UTL_RAW.cast_to_varchar2(VALUE),
                                 'ZHS16GBK',
                                 'AL32UTF8');
    DBMS_OUTPUT.put_line(l_HTTP_RETURN_MSG);

    if l_return_msg = '0' then
      return '0';
    END IF;

l_return_json:=json(l_HTTP_RETURN_MSG);

 l_media_id:=json_ext.get_string(l_return_json, 'media_id');
 return l_media_id;
 
  exception
    when others then
      o_error_message := '**Error line: ' ||
                         dbms_utility.format_error_backtrace() || '-' ||
                         '**Error info: ' || SQLERRM;
                         dbms_output.put_line(o_error_message);
                         return '0';
  end;
  procedure sendmsg_text(i_webhook varchar2, i_content_text varchar2) is
    o_error_message varchar2(4000);
    l_post_data     clob;
    l_post_data2 BLOB;
    L_RETURN_MSG    varchar2(4000);
    L_content_text  varchar2(2000);
    l_NLS_CHARACTERSET varchar2(200);
  begin
    L_content_text :=  replace_fun(i_content_text);
    select value into l_NLS_CHARACTERSET from nls_database_parameters where parameter= 'NLS_CHARACTERSET';
    if l_NLS_CHARACTERSET ='ZHS16GBK'  then 
    L_content_text:=rtrim(CONVERT((L_content_text), 'AL32UTF8', 'ZHS16GBK'),chr(0));
    end if;
  
    l_post_data    := '
    {
    "msgtype": "text",
    "text": {"content": "'||L_content_text||'"}}';
l_post_data2:=UTL_RAW.cast_to_raw(c => l_post_data);
--l_post_data:=CONVERT(l_post_data, 'AL32UTF8', 'ZHS16GBK');

                            
 -- l_post_data2:= Clob2Blob(l_post_data);
   
    L_RETURN_MSG   := POST(i_url       => 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=' ||
                                          i_webhook,
                           i_post_data => l_post_data2);
                           
     --     dbms_output.put_line(L_content_text);

     --   dbms_output.put_line(l_post_data);
                      
    dbms_output.put_line(L_RETURN_MSG);
  
  exception
    when others then
      o_error_message := '**Error line: ' ||
                         dbms_utility.format_error_backtrace() || '-' ||
                         '**Error info: ' || SQLERRM;
      Raise_application_error(-20001, o_error_message);
  end;

  procedure sendmsg_file(i_webhook  varchar2,
                         i_dir      varchar2,
                         i_file_name varchar2,
                         i_display_file_name varchar2) is
    o_error_message varchar2(4000);
    l_post_data varchar2(1000);
    l_media_id varchar2(1000);
    L_RETURN_MSG varchar2(4000);
  begin
    l_media_id:=upload_media(i_webhook           => i_webhook,
                                      I_db_Path           => i_dir,
                                      i_file_name         => i_file_name,
                                      i_display_file_name => i_display_file_name);
                                      if l_media_id='0' then 
                                            Raise_application_error(-20001, '上传文件失败');  
                                      end if;
                                      
   l_post_data    := '
    {
    "msgtype": "file",
    "file": {
         "media_id": "'||l_media_id||'"
    }
}';
  
    L_RETURN_MSG   := POST(i_url       => 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=' ||
                                          i_webhook,
                           i_post_data => l_post_data);
                           
     --     dbms_output.put_line(L_content_text);

     --   dbms_output.put_line(l_post_data);
                      
    dbms_output.put_line(L_RETURN_MSG);

  exception
    when others then
      o_error_message := '**Error line: ' ||
                         dbms_utility.format_error_backtrace() || '-' ||
                         '**Error info: ' || SQLERRM;
      Raise_application_error(-20001, o_error_message);
  end;

  procedure sendmsg_image(i_webhook   varchar2,
                          i_dir       varchar2,
                          i_imagename varchar2) is
    o_error_message varchar2(4000);
    l_image_base64  clob;
    l_image_blob    blob;
    l_image_bfile   BFILE;
    dest_offset     INTEGER := 1;
    src_offset      INTEGER := 1;
    l_md5           varchar2(100);
    L_POST_DATA     clob;
    L_RETURN_MSG    VARCHAR2(4000);
  begin
  
    --
    dbms_lob.createtemporary(l_image_blob, TRUE);
    l_image_bfile := BFILENAME(i_dir, i_imagename);
    IF dbms_lob.isopen(l_image_bfile) <= 0 THEN
      dbms_lob.open(l_image_bfile);
      dbms_lob.loadblobfromfile(l_image_blob,
                                l_image_bfile,
                                dbms_lob.lobmaxsize,
                                dest_offset,
                                src_offset);
      dbms_lob.close(l_image_bfile);
    ELSE
      dbms_lob.loadblobfromfile(l_image_blob,
                                l_image_bfile,
                                dbms_lob.lobmaxsize,
                                dest_offset,
                                src_offset);
      dbms_lob.close(l_image_bfile);
    END IF;
    dbms_lob.createtemporary(l_image_base64, TRUE);
    to_base64(l_image_base64, l_image_blob);
  
    l_image_base64 := regexp_replace(l_image_base64,
                                     CHR(13) || chr(10),
                                     NULL,
                                     1,
                                     0,
                                     'i');
    --
    l_md5 := lower(sys.dbms_crypto.HASH(l_image_blob, 2));
    --   l_md5:= utl_raw.cast_to_raw(apex_030200.wwv_crypt.md5lob(l_image_blob));
    dbms_lob.freetemporary(l_image_blob);
  
    DBMS_OUTPUT.put_line(i_dir);
    DBMS_OUTPUT.put_line(i_imagename);
  
    dbms_output.put_line(l_md5);
  
    dbms_lob.createtemporary(L_POST_DATA, TRUE);
    dbms_lob.open(L_POST_DATA, DBMS_LOB.LOB_READWRITE);
    dbms_lob.append(L_POST_DATA,
                    '{"msgtype": "image",
    "image": {
        "base64": "');
  
    dbms_lob.append(L_POST_DATA, l_image_base64);
    dbms_lob.append(L_POST_DATA,
                    '",
        "md5": "');
    dbms_lob.append(L_POST_DATA, l_md5);
    DBMS_LOB.append(L_POST_DATA,
                    '"
    }
}');
  

    dbms_lob.close(L_POST_DATA);
  
    --dbms_output.put_line(substr(l_image_base64,1,20));
    --dbms_output.put_line(L_POST_DATA);
    L_RETURN_MSG := POST(i_url       => 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=' ||
                                        i_webhook,
                         i_post_data => L_POST_DATA);
    dbms_lob.freetemporary(l_image_base64);
    dbms_lob.freetemporary(L_POST_DATA);
    dbms_output.put_line(L_RETURN_MSG);
  
  exception
    when others then
      o_error_message := '**Error line: ' ||
                         dbms_utility.format_error_backtrace() || '-' ||
                         '**Error info: ' || SQLERRM;
      Raise_application_error(-20001, o_error_message);
  end;

  

end qyapi_weixin_robot_sql;
/
