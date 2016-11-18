require 'htmlentities'

class Bot < ActiveRecord::Base
  has_many :weixin_contacts
  has_and_belongs_to_many :weixin_publics

  USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/48.0.2564.109 Safari/537.36'
  SPECIAL_USERS = [
    'newsapp', 'fmessage', 'filehelper', 'weibo', 'qqmail',
    'fmessage', 'tmessage', 'qmessage', 'qqsync', 'floatbottle', 'lbsapp',
    'shakeapp', 'medianote', 'qqfriend', 'readerapp', 'blogapp', 'facebookapp',
    'masssendapp', 'meishiapp', 'feedsapp', 'voip', 'blogappweixin', 'weixin',
    'brandsessionholder', 'weixinreminder', 'wxid_novlwrv3lqwv11', 'gh_22b87fa7cb3c',
    'officialaccounts', 'notification_messages', 'wxid_novlwrv3lqwv11', 'gh_22b87fa7cb3c',
    'wxitil', 'userexperience_alarm', 'notification_messages'
  ]

  APPID = 'wx782c26e4c19acffb'
  LANG = 'zh_CN'
  PUBLIC_WEIXIN = ["2892634610"]


  def initialize(attributes = nil, options = {})
    super(attributes, options)
    @uuid = nil
    @redirect_url = nil
    @base_url = nil
    @message = nil
    @base_request = {}
    @ticket = ""
    @public_user_list = []
    @group_list = []  # 群组
    @special_user = [] # 特殊账户
    @cookies = {}
    @host = ""
    @retcode = '0'
  end

  def get_qrcode
    # 1.get uuid
    p '获取二维码'
    @uuid = getUUID
    # 2.show_url
    show_url = show_qrcode(@uuid)
    p show_url
    [@uuid, show_url]
  end

  def get_weixin_bot(uuid)
    # 3.wait login
    p "请扫码"
    while waitLogin(1,uuid)
      p "点击确定"
      while waitLogin(0,uuid)
        # 扫码登陆login
        p "正在登陆"
        weixin_bot = login
        break
      end
      break
    end
    weixin_bot
  end

  def start(uin)
        weixin_bot = WeixinBot.find_by_weixin_uin uin
        # 初始化微信
        p '正在初始化微信'
        wxinit(weixin_bot)
        wx_status_notify(weixin_bot)
        # 获取联系人
        p "正在获取联系人"
        get_contact(weixin_bot)
        # p "获取群组"
        # get_betch_contact(weixin_bot,[])
        # p "获取头像"
        # get_icon(uin)
        testsynccheck(weixin_bot)
        p "同步消息"
        sync(weixin_bot)
        p "保持心跳连接"

  end

  def getUUID
    url = 'https://login.weixin.qq.com/jslogin'
    params = {
      'appid': APPID,
      'fun': 'new',
      'lang': LANG,
      '_': real_time
    }
    response = wx_post(url,params,'')
    data = response.scan(/window.QRLogin.code = (\d+); window.QRLogin.uuid = "(\S+?)"/)
    if !data[0].blank?
      code = data[0][0]
      @uuid = data[0][1]
      return @uuid
    end
    return nil
  end

  def show_qrcode(uuid)
    url = 'https://login.weixin.qq.com/qrcode/' + uuid
  end

  def waitLogin(interval,uuid)
    sleep(interval)
    url = "https://login.weixin.qq.com/cgi-bin/mmwebwx-bin/login?tip=#{interval}&uuid=#{uuid}&_=#{real_time}"
    response = wx_get(url,'')
    data = response.scan(/window.code=(\d+)/)
    code = data[0][0]

    if code == '201'
      return true
    elsif code == '200'
      urls = response.scan(/window.redirect_uri=\"(\S+?)\"/)
      url = urls[0][0] + '&fun=new&version=v2'
      @redirect_uri = url
      p @redirect_uri
      @base_url = @redirect_uri.split("/")[2]
      return true
    elsif code == '408'
      @message = '[登陆超时]'
      return false
    else
      @message = '[登陆异常]'
      return false
    end
  end

  def login
    data = wx_get(@redirect_uri,'')
    p data
    if data.include?("OK")
      skey = data.scan(/<skey>(\S+?)<\/skey/)[0][0]
      wxsid = data.scan(/<wxsid>(\S+?)<\/wxsid/)[0][0]
      wxuin = data.scan(/<wxuin>(\S+?)<\/wxuin/)[0][0]
      @ticket = data.scan(/<pass_ticket>(\S+?)<\/pass_ticket/)[0][0]
      @base_request['Uin'] = wxuin
      @base_request['Sid'] = wxsid
      @base_request['Skey'] = skey
      @base_request['DeviceID'] = "e" + rand(100000000000000..999999999999999).to_s
      weixin_bot = WeixinBot.find_or_create_by(weixin_uin: wxuin)
      weixin_bot.ticket = data.scan(/<pass_ticket>(\S+?)<\/pass_ticket/)[0][0]
      weixin_bot.base_request = @base_request.to_json
      weixin_bot.cookies = data.cookies.to_json
      weixin_bot.is_logout = 0
      weixin_bot.base_url = @base_url
      weixin_bot.save
    end
    weixin_bot
  end

  def wxinit(weixin_bot)
    base_request = JSON.parse weixin_bot.base_request
    url = "https://#{weixin_bot.base_url}/cgi-bin/mmwebwx-bin/webwxinit?pass_ticket=#{weixin_bot.ticket}&skey=#{base_request['Skey']}&r=#{real_time}"
    params = {
      'BaseRequest': base_request
    }
    response = JSON.parse(wx_post(url,params.to_json, weixin_bot.weixin_uin) )
    @user = response["User"]
    p @user
    name = response["User"]["NickName"]
    @synckey = response["SyncKey"]
    @synckey_text = response["SyncKey"]["List"].map{|e| e.values.join("_")}.join("|")

    weixin_bot.synckey = @synckey.to_json
    weixin_bot.synckey_text = @synckey_text
    weixin_bot.user_information = @user.to_json
    weixin_bot.name = name
    # weixin_bot.is_logout = 0
    weixin_bot.is_check = 0
    weixin_bot.save
  end

  def wx_status_notify(weixin_bot)
    user = JSON.parse weixin_bot.user_information
    url = "https://#{weixin_bot.base_url}/cgi-bin/mmwebwx-bin/webwxstatusnotify?lang=zh_CN&pass_ticket=#{weixin_bot.ticket}"
    params = {
      'BaseRequest': JSON.parse(weixin_bot.base_request),
      'Code': 3,
      'FromUserName': user["UserName"],
      'ToUserName': user["UserName"],
      'ClientMsgId': real_time
    }
    response = JSON.parse(wx_post(url,params.to_json, weixin_bot.weixin_uin) )
  end

  def get_icon(uin)
    url = "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxgeticon?username=#{@user["UserName"]}&skey=#{@base_request["Skey"]}"
    p url
    response = wx_get(url, uin)
  end

  def get_contact(weixin_bot)
    base_request = JSON.parse weixin_bot.base_request
    url = "https://#{weixin_bot.base_url}/cgi-bin/mmwebwx-bin/webwxgetcontact?pass_ticket=#{weixin_bot.ticket}&skey=#{base_request['Skey']}&r=#{real_time}"
    response = JSON.parse(wx_post(url,{'BaseRequest': base_request}.to_json, weixin_bot.weixin_uin) )
    # p response
    @member_count = response["MemberCount"]
    @member_list = response["MemberList"]
    @contact_list = @member_list
    @contact_list.each do |member|
      if SPECIAL_USERS.include?(member["UserName"])
        @special_user << member
        @contact_list.delete(member)
      elsif member["VerifyFlag"] != 0  # 公众号/服务号
        save_public(member, weixin_bot) if weixin_bot.weixin_uin.in? PUBLIC_WEIXIN
        @public_user_list << member
        @contact_list.delete(member)
      elsif member["UserName"].include?("@@")  # 群聊
        save_contact(member, weixin_bot)
        @group_list << member
        @contact_list.delete(member)
      elsif member["UserName"] == @user["UserName"]
        @contact_list.delete(member)
      else
        save_contact(member, weixin_bot)
      end
    end
  end

  def get_betch_contact(weixin_bot, group_list)
    # weixin_bot.group_list = @group_list.to_json
    # weixin_bot.save
    if group_list.blank?
      group_list = weixin_bot.weixin_contacts.where("contact_type = 2").pluck(:user_name)
    end

    url = "https://#{weixin_bot.base_url}/cgi-bin/mmwebwx-bin/webwxbatchgetcontact?type=ex&r=#{real_time}&pass_ticket=#{@ticket}"
    list = []
    group_list.map{|e| list << {"UserName": e, "EncryChatRoomId":""} }
    p "group_list size ----------" + group_list.size.to_s
    list.each_slice(50) do |list_slice|
      params = {
          'BaseRequest': @base_request,
          "Count": group_list.size,
          "List": list_slice
      }

      response = JSON.parse(wx_post(url,params.to_json, weixin_bot.weixin_uin) )
      p "二次获取联系人"
      p response["ContactList"].size
      response["ContactList"].each do |member|
        if member["VerifyFlag"] != 0  # 公众号/服务号=-51 1
          save_public(member, weixin_bot) if weixin_bot.weixin_uin.in? PUBLIC_WEIXIN
        else
          save_contact(member, weixin_bot)
        end
      end
    end

    # RumourSource.new.sync_weixin_public
    puts "--------"
    puts weixin_bot.weixin_uin.in? PUBLIC_WEIXIN
    puts "--------"
    RumourSource.sync_weixin_public if weixin_bot.weixin_uin.in? PUBLIC_WEIXIN
  end

  def sync_check(weixin_bot)
    base_request = JSON.parse weixin_bot.base_request
    begin
      params = {
        'synckey': CGI.escape(weixin_bot.synckey_text),
        'skey': CGI.escape(base_request['Skey']),
        'uin': base_request['Uin'],
        'r': real_time,
        'deviceid': base_request['DeviceID'],
        'sid': base_request['Sid'],
        '_': check_time
      }

      url = 'https://' + weixin_bot.base_url + '/cgi-bin/mmwebwx-bin/synccheck?' + params.map{|e| e.join("=")}.join("&")
      response = wx_get(url, base_request['Uin']).scan(/[\d]/)
      weixin_bot.retcode = retcode = response[0]
      weixin_bot.selector = selector = response[1]
      # weixin_bot.is_logout = retcode == 0 ? 0 : 1
      weixin_bot.is_logout = 0 if retcode.to_i == 0
      weixin_bot.save
      [retcode, selector]
      p [retcode, selector]
    rescue
      Rails.logger.error("sync_check error ")
    end

  end

  def test_sync_check(host, weixin_bot)
    base_request = JSON.parse weixin_bot.base_request
    begin
      params = {
        'synckey': CGI.escape(weixin_bot.synckey_text),
        'skey': CGI.escape(base_request['Skey']),
        'uin': base_request['Uin'],
        'r': real_time,
        'deviceid': base_request['DeviceID'],
        'sid': base_request['Sid'],
        '_': real_time
      }

      url = 'https://' + host + '/cgi-bin/mmwebwx-bin/synccheck?' + params.map{|e| e.join("=")}.join("&")
      response = wx_get(url, base_request['Uin']).scan(/[\d]/)
      retcode = response[0]
      selector = response[1]
      [retcode, selector]
      p [retcode, selector]
    rescue
      Rails.logger.error("test sync_check error ")
    end

  end

  def testsynccheck(weixin_bot)
    # update_device_id
    base_request = JSON.parse weixin_bot.base_request
    hosts = [
      "webpush.wx.qq.com",
      'webpush.weixin.qq.com',
      'webpush2.weixin.qq.com',
      'webpush.wechat.com',
      'webpush1.wechat.com',
      'webpush2.wechat.com'
    ]

    hosts.each do |host|
      result = test_sync_check(host, weixin_bot)
      if result[0] == "0"
        # @host = host
        p "同步线路测试成功"
        weixin_bot = WeixinBot.where("weixin_uin = ?", base_request['Uin']).first
        weixin_bot.sync_host = host
        weixin_bot.save
        break
      end
    end
  end

  def listen_msg
    while true
      sleep(1)
      p Time.now
      WeixinBot.all.each do |weixin_bot|
        if weixin_bot.is_logout == 0 && weixin_bot.is_check == 0
          puts  "------------------work sidekiq"
          weixin_bot.is_check = 1
          weixin_bot.save
          WeixinListen.perform_async(weixin_bot.weixin_uin)
        end
      end
    end


    # WeixinListen.perform_async(@base_request['Uin'])
    # weixin_bot = WeixinBot.where("weixin_uin = ?", uin).first
    # retcode = '0'
    # while retcode == '0'
    #   begin
    #     time = Time.now
    #     p time
    #     result = sync_check(weixin_bot)
    #     retcode, selector = result[0], result[1]
    #     if retcode == "1100"
    #       p '你在手机登出了微信'
    #       Rails.logger.error("你在手机登出了微信")
    #       break
    #     elsif retcode == "1101"
    #       p "你在其他地方登陆了WEB版微信"
    #       Rails.logger.error("你在其他地方登陆了WEB版微信")
    #       break
    #     elsif retcode == '0'
    #       if selector == '0'
    #         sleep(1)
    #       else
    #         p "同步新消息"
    #         sync(weixin_bot)
    #       end
    #     end

    #     if Time.now - time <= 20
    #       sleep(Time.now - time)
    #     end
    #   rescue Exception => e
    #     Rails.logger.error("listen_msg error #{e.message}")
    #   end
    # end
  end

  # 同步新消息包括公众号文章
  def sync(weixin_bot)
    base_request = JSON.parse(weixin_bot.base_request)
    url = "https://#{weixin_bot.base_url}/cgi-bin/mmwebwx-bin/webwxsync?sid=#{base_request["Sid"]}&skey=#{base_request["Skey"]}&pass_ticket=#{weixin_bot.ticket}"
    params = {
      "BaseRequest": base_request,
      "SyncKey": JSON.parse(weixin_bot.synckey),
      "rr": -real_time
    }
    response = JSON.parse(wx_post(url, params.to_json, base_request['Uin']))
    p response
    if response['BaseResponse']['Ret'] == 0
      @synckey = response['SyncKey']
      weixin_bot.synckey = @synckey.to_json
      weixin_bot.synckey_text = @synckey_text = response["SyncKey"]["List"].map{|e| e.values.join("_")}.join("|")
      new_group_ids = response["AddMsgList"][0]["StatusNotifyUserName"].split(",")#.select{|e| e[1] == "@"}
      get_betch_contact(weixin_bot, new_group_ids) if new_group_ids.present?
    end
    weixin_bot.save
    p parser_text(response) if response.include?("CDATA")
  end

  # 所有群聊发送消息content
  def send_msg_to_group(content, weixin_bot)
    group_list = JSON.parse weixin_bot.group_list
    group_list.each do |group|
      send_msg(content, group["UserName"], weixin_bot)
    end
  end

  def send_msg(content, to, weixin_bot)
    client_msg_id = Time.now.to_i.to_s + rand(1000000..9999999).to_s
    url = "https://#{weixin_bot.base_url}/cgi-bin/mmwebwx-bin/webwxsendmsg?pass_ticket=#{weixin_bot.ticket}"
    params = {
      'BaseRequest': weixin_bot.base_request,
      'Msg': {
          "Type": 1,
          "Content": content,
          "FromUserName": JSON.parse(weixin_bot.user_information)["UserName"],
          "ToUserName": to,
          "LocalID": client_msg_id,
          "ClientMsgId": client_msg_id
      }
    }

    response = JSON.parse(wx_post(url, params.to_json, weixin_bot.weixin_uin))
  end

  # 建群聊
  def create_chat_room(topic, user_ids, weixin_bot)
    topic = topic || ''
    member_list = []
    user_ids.map { |e| member_list << {"UserName": e} }
    url = "https://#{weixin_bot.base_url}/cgi-bin/mmwebwx-bin/webwxcreatechatroom?r=#{real_time}&pass_ticket=#{weixin_bot.ticket}"
    params = {
      'Topic': topic,
      'BaseRequest': weixin_bot.base_request,
      'MemberList': member_list,
      'MemberCount': user_ids.size
    }

    response = JSON.parse(wx_post(url, params.to_json, weixin_bot.weixin_uin))
    if response["BaseResponse"]["Ret"] == 0
      room_name = response["ChatRoomName"]
      send_msg(topic, room_name, weixin_bot)
      # save to mysql
      weixin_contact = WeixinContact.find_or_create_by(weixin_bot_id: weixin_bot.id, nick_name: topic)
      weixin_contact.user_name = room_name
      weixin_contact.contact_type = 2 if weixin_contact.user_name[1] == "@"
      weixin_contact.save!
      1
    else
      0
    end
  end

  def upload_media(file, weixin_bot, ids)
    url = "https://file.wx.qq.com/cgi-bin/mmwebwx-bin/webwxuploadmedia?f=json"
    media_count = 0
    file_name = file
    # mime_type = application/pdf, image/jpeg, image/png, etc.
    mime_type = file_name.path.last(3) == 'png' ? 'image/png' : 'image/jpeg'
    media_type = 'pic'
    last_modifie_date = 'Mon Nov 30 2015 12:00:00 GMT+0800 (CST)'

    pass_ticket = weixin_bot.ticket
    client_media_id = real_time
    webwx_data_ticket = JSON.parse(weixin_bot.cookies)["webwx_data_ticket"]
    file_size = file_name.size

    params = {
              "BaseRequest": JSON.parse(weixin_bot.base_request),
              "ClientMediaId": client_media_id,
              "TotalLen": file_size,
              "StartPos": 0,
              "DataLen": file_size,
              "MediaType": 4
            }


    fields={
              'id': 'WU_FILE_' + media_count.to_s,
              'name': file_name.path.split("/")[-1],
              'type': mime_type,
              'lastModifieDate': last_modifie_date,
              'size': file_size.to_s,
              'mediatype': media_type,
              'uploadmediarequest': params.to_json,
              'webwx_data_ticket': webwx_data_ticket,
              'pass_ticket': pass_ticket,
              'filename': file_name,
              'multipart': true
            }

    headers={
              'Host': 'file.wx.qq.com',
              'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.5',
              'Accept-Encoding': 'gzip, deflate',
              'Referer': 'https://wx.qq.com/?&lang=zh_CN',
              'Content-Type': 'multipart/form-data; boundary=----WebKitFormBoundaryNSSE8tg8TfGUFjEZ',
              'Origin': 'https://wx.qq.com',
              'Connection': 'keep-alive',
              'Pragma': 'no-cache',
              'Cache-Control': 'no-cache'
            }

    cookies = weixin_bot.blank? ? {} : JSON.parse(weixin_bot.cookies)
    response = RestClient::Request.execute(
      :method => :post,
      :url => url,
      :cookies => cookies,
      :payload => fields,
      :headers => headers
    )

    media_id = JSON.parse(response)["MediaId"]
    ids.each do |id|
      begin
        send_msg_img(weixin_bot, id, media_id)
      rescue Exception => e
        Rails.logger.error("#{@weixin_bot.name} send_msg error #{id}")
      end
    end
    # {BaseResponse: {Ret: 0, ErrMsg: ""},…}
    #   BaseResponse
    #   :
    #   {Ret: 0, ErrMsg: ""}
    #   CDNThumbImgHeight:56
    #   CDNThumbImgWidth:100
    #   MediaId:"@crypt_38524e62_007839b5bff9d15f949c1bc70aa67749fd4566e05dfd9d7275147964d5641dd510b28f61638222e9f1371f139d2fdd425b7db9a254d16f264ecccdf472fe51c778192b63192128b30017dd2f21cdafaf759d662d03efb3d24dd9ffddf07dfedfe7e78df10aa01eb402874c319a14c59c5e64f69dba5da6bf69963d7de3685e3baf0c441aadb7b126eff58e8580bfc6e6d0715769172e75320dc8be6ff779104bcf0c8243bd947f7c1134bfeda38be2da8e3164a90a672ee7b583873996c74cf3e64cd10e59e8ee0a9bcc8408bca98364c30ed97cec81220b4f1227f4ef195ec39fb5700fd03647a682ba38f43872fe27e13b58ef90532498ef21b8191f2eeaf662b5919e3db898365fe7d084aad77658fbba395539b9ee2fd350827f205cfd0bdf0c25c314f5bbe19fb3462211bee4ec9472c23a990d5cca30f3ed6d163faecf1e474a4135d4b2e43bcaf2b5524ca336e5234a7ce58b770e51003c1045c3de88"
    #   StartPos:21646

  end

  def send_msg_img(weixin_bot, to, media_id)
    url = "https://#{weixin_bot.base_url}/cgi-bin/mmwebwx-bin/webwxsendmsgimg?fun=async&f=json&lang=zh_CN&pass_ticket=#{weixin_bot.ticket}"
    client_msg_id = Time.now.to_i.to_s + rand(1000000..9999999).to_s
    params = {
      "BaseRequest": weixin_bot.base_request,
      "Msg": {
        "Type": 3,
        "MediaId": media_id,
        "FromUserName": JSON.parse(weixin_bot.user_information)["UserName"],
        "ToUserName": to,
        "LocalID": client_msg_id,
        "ClientMsgId": client_msg_id
      }
    }

    response = JSON.parse(wx_post(url, params.to_json, weixin_bot.weixin_uin))
  end

  private

  def real_time
    Time.now.to_i * 1000
  end

  def check_time
    @check_time = @check_time.present? ? (@check_time.to_i + 1).to_s : Time.now.to_i.to_s + rand(100..999).to_s
  end

  def update_device_id
     @base_request['DeviceID'] = "e" + rand(100000000000000..999999999999999).to_s
  end

  def wx_get(url,uin)
    weixin_bot = WeixinBot.where("weixin_uin = ?", uin).first
    cookies = weixin_bot.blank? ? {} : JSON.parse(weixin_bot.cookies)
    response = RestClient::Request.execute(
      :method => :get,
      :url => url,
      :cookies => cookies,
      :headers => {"Refer" => 'https://wx.qq.com/','charset' => "UTF-8",'Content-Type' => 'text/html', 'User-Agent' => USER_AGENT}
    )
    if weixin_bot.present? && response.cookies.present?
      cookies = cookies.merge(response.cookies)
      weixin_bot.cookies = cookies.to_json
      weixin_bot.save
    end
    response
  end

  def wx_post(url,params, uin)
    weixin_bot = WeixinBot.where("weixin_uin = ?", uin).first
    cookies = weixin_bot.blank? ? {} : JSON.parse(weixin_bot.cookies)
    response = RestClient::Request.execute(
      :method => :post,
      :url => url,
      :cookies => cookies,
      :payload => params,
      :headers => {'charset' => "UTF-8",'Content-Type' => 'text/html', 'User-Agent' => USER_AGENT}
    )
    if response.cookies.present?
      cookies = cookies.merge(response.cookies)
      weixin_bot.cookies = cookies.to_json
      weixin_bot.save
    end
    response
  end

  def parser_text(content)
    results = {}
    coder = HTMLEntities.new
    xml = Nokogiri.XML(coder.decode(content["AddMsgList"][0]["Content"]).gsub("<br/>",""))
    name = xml.css("name").map{|e| e.content}.uniq
    titles = xml.css("title").map{|e| e.content}.uniq
    urls = xml.css("url").map{|e| e.content}.uniq
    results[:name] = name
    results[:articles] = []
    1.upto(titles.size) do |i|
      results[:articles] << {:title => titles[i-1], :url => urls[i-1]}
    end
    results
  end

  def save_public(member, weixin_bot)
    weixin_public = WeixinPublic.find_or_create_by(alias: member["Alias"])
    weixin_public.update_attributes(:nick_name => member["NickName"],:user_name => member["UserName"],:img_url => member["HeadImgUrl"],:sex => member["Sex"],:member_count => member["MemberCount"])
    weixin_public.weixin_bots << weixin_bot
    weixin_public.save!
  end

  def save_contact(member, weixin_bot)
    if member["NickName"].present?
      nick_name = ActionView::Base.full_sanitizer.sanitize(member["NickName"])
      weixin_contact = WeixinContact.find_or_create_by(weixin_bot_id: weixin_bot.id, nick_name: nick_name)
      weixin_contact.update_attributes(:user_name => member["UserName"],:img_url => member["HeadImgUrl"],:sex => member["Sex"],:member_count => member["MemberCount"])
      weixin_contact.contact_type = 2 if weixin_contact.user_name[1] == "@"
      weixin_contact.save!
      p weixin_contact
    end
  end
end


