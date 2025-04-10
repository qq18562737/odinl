from selenium.common import TimeoutException
from selenium.webdriver.common.by import By
import undetected_chromedriver as uc_local
import seleniumwire.undetected_chromedriver as uc
import sys
import subprocess
import os
import warnings
import logging
import time
import random
from xvfbwrapper import Xvfb
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from bs4 import BeautifulSoup
import urllib.parse
import re
import json
from selenium.webdriver.common.action_chains import ActionChains
from anticaptchaofficial.imagecaptcha import *
#https://anti-captcha.com/
import string
import logging

logging.basicConfig(
    #level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/root/tmp/script.log'),
        logging.StreamHandler()  # 同时输出到控制台
    ]
)

reqids = [] 
lastload = 0

# 处理网络请求的函数
def mylousyprintfunction(message):
    global reqids, lastload
    lastload = time.time()
    try:
        print(message)
        doc_url =message['params']['documentURL'] 
        print(doc_url)
        if doc_url.startswith("com."):
            print("$RESULT$:" + doc_url)
            exit()
    except:
            print("doc_url error")
    print("there: ", message['params']['headers'][':authority'], message['params']['headers'][':path'])
    #if message['params']['headers'][':authority'] == 'accounts.google.com':
    #    if message['params']['headers'][':path'].startswith('/signin/oauth/consent?'):
    #        reqid = message["params"]["requestId"]
    #        print("setting req id", message["params"]["requestId"])
    if message['params']['headers'][':authority'] == 'accounts.google.com':
        reqids.append(message["params"]["requestId"])
        print("path: ", message['params']['headers'][':path'])
        path = message['params']['headers'][':path']
        if "/_/signin/oauth/id" in path or "/signin/oauth/consent?" in path:
            reqids.append(message["params"]["requestId"])
            print("setting req id", reqids)

# 从HTML中提取凭证响应
def extract_credential_response(html):
  soup = BeautifulSoup(html, 'html.parser')
  div = soup.find('div', attrs={'data-credential-response': True})
  if div:
    try:
      # Assuming the value is a JSON string, parse it
      print("d1", div['data-credential-response'])
      decoded_url = div['data-credential-response']
      decoded_url = urllib.parse.unquote(decoded_url).encode().decode('unicode_escape')
      print("d2", decoded_url)
      match = re.search(r'code=([^&]+)', decoded_url)  # Look for "code\u003d"
      print("m", match)
      if match:
          print(match.group(1))
          return "http://rolf/?code=" + match.group(1)
      return None
    except json.JSONDecodeError:
      print("Error: 'data-credential-response' value is not valid JSON.")
      return None
  else:
    print("Error: No div with 'data-credential-response' attribute found.")
    return None

# 检查版本函数
def check_versions():
    try:
        chrome_version = subprocess.run(['google-chrome', '--version'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True).stdout.strip()
    except Exception as e:
        chrome_version = f"Google Chrome not found or not executable: {str(e)}"

    try:
        chromedriver_version = subprocess.run(['chromedriver', '--version'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True).stdout.strip()
    except Exception as e:
        chromedriver_version = f"ChromeDriver not found or not executable: {str(e)}"

    print(f"Chrome 版本: {chrome_version}")
    print(f"ChromeDriver 版本: {chromedriver_version}")

# 主要的OdinRegistrationBot类
class OdinRegistrationBot:
    def __init__(self):
        # 初始化Bot
        self.version_main = int(
            str(subprocess.run(["chromedriver", "-v"], stdout=subprocess.PIPE).stdout).split(" ")[1].split(".")[0])
        self.driver = None
        self.proxy = None
        self.step = "start"
        self.lastload = time.time()
        print(f"Chrome 版本獲取: {self.version_main}")

    @staticmethod
    def driver_arguments(chrome_options):
        # 设置Chrome驱动的参数
        # chrome_options.add_argument('--no-sandbox')
        # chrome_options.add_argument('--disable-dev-shm-usage')
        # chrome_options.add_argument('--disable-gpu')
        # chrome_options.add_argument('--headless=new')
        # chrome_options.add_argument('--ignore-certificate-errors')  # 忽略证书错误
        # chrome_options.add_argument('--allow-running-insecure-content')  # 允许不安全内容
        # chrome_options.add_argument('--lang=zh-CN')  # 设置中文语言
        # chrome_options.add_argument('--disable-features=NetworkService')
        # chrome_options.add_argument('--disable-http2')
        # # 浏览器优化选项
        # chrome_options.add_argument('--disable-extensions')
        # chrome_options.add_argument('--dns-prefetch-disable')
        # chrome_options.add_argument('--disable-gpu-sandbox')

                # 设置Chrome驱动的参数
        chrome_options.add_argument(f'--no-first-run --no-service-autorun --password-store=basic')
        chrome_options.add_argument(f'--disable-gpu')
        chrome_options.add_argument(f'--no-sandbox')
        chrome_options.add_argument('--ignore-ssl-errors=yes')
        chrome_options.add_argument('--ignore-certificate-errors')
        chrome_options.add_argument(f'--disable-dev-shm-usage')
        chrome_options.add_argument(f'--disable-component-update')



        return chrome_options

    def run_chrome(self, proxy):
        # 启动Chrome浏览器
        current_timestamp = int(time.time() * 1000)  # 毫秒级时间戳
        password = f"593chgaqlksdyh91_country-us_session-{current_timestamp}_lifetime-5m"

        proxy_config = None
        if proxy and proxy.strip():
            try:
                proxy_config = json.loads(proxy)
            except json.JSONDecodeError:
                print(f"警告: 代理设置格式错误，将不使用代理: {proxy}")
                proxy_config = None
        
        chrome_options = uc.ChromeOptions()
        opts = self.driver_arguments(chrome_options)
        
        if proxy_config and proxy_config.get('username') and proxy_config.get('type') in ['socks5', 'http']:
            # 认证代理配置
            if proxy_config['type'] == 'socks5':
                proxy_http = f"socks5://{proxy_config['username']}:{proxy_config['password']}@{proxy_config['ip']}:{proxy_config['port']}"
                proxy_https = proxy_http
            else:
                proxy_http = f"http://{proxy_config['username']}:{proxy_config['password']}@{proxy_config['ip']}:{proxy_config['port']}"
                proxy_https = f"http://{proxy_config['username']}:{proxy_config['password']}@{proxy_config['ip']}:{proxy_config['port']}"

                #proxy_http = f"http://{proxy_config['username']}:{password}@{proxy_config['ip']}:{proxy_config['port']}"
                #proxy_https = f"http://{proxy_config['username']}:{password}@{proxy_config['ip']}:{proxy_config['port']}"

            sel_options = {
                'proxy': {
                    'http': proxy_http,
                    'https': proxy_https,
                    'no_proxy': 'localhost,127.0.0.1'
                },
                'verify_ssl': False, # 禁用SSL验证
                'connection_timeout': 60,  # 增加超时时间
                'suppress_connection_errors': True  # 抑制连接错误
            }
            
            print(f"使用认证代理: {proxy_http}")
            self.driver = uc.Chrome(
                seleniumwire_options=sel_options,
                options=opts,
                headless=False,
                version_main=self.version_main
                #enable_cdp_events=True
            )
            print("代理设置完成")

        elif proxy_config and proxy_config.get('ip'):
            # 无认证代理配置
            proxy_url = f"{proxy_config.get('type', 'http')}://{proxy_config['ip']}:{proxy_config['port']}"
            print(f"使用无认证代理: {proxy_url}")
            opts.add_argument(f'--proxy-server={proxy_url}')
            self.driver = uc.Chrome(
                options=opts,
                headless=False,
                version_main=self.version_main,
                enable_cdp_events=True
            )
            
        else:
            # 无代理模式
            print("不使用代理")
            self.driver = uc.Chrome(
                options=opts,
                headless=False,
                version_main=self.version_main,
                enable_cdp_events=True
            )

        print("设置全局")
        global driver
        driver = self.driver

        # print("查看代理IP")
        # try:
        #     driver.get("http://httpbin.org/ip")        
        #     # 获取页面内容
        #     ip_info = driver.find_element(By.TAG_NAME, 'pre').text
        #     print(f"当前IP信息:\n{ip_info}")

        # except Exception as e:
        #     self.log_step(f"查看IP出错: {str(e)}")


       

    # ... [保持其他方法不变，包括registration_process, log_step, click_google_login等] ...
    @staticmethod
    def get_captcha_code(image):
        # 使用第三方服务解决验证码
        solver = imagecaptcha()
        solver.set_verbose(1)
        solver.set_key("381ff235dbaba0a12dd72aabcbae2938")
        print("account balance: " + str(solver.get_balance()))
        captcha_text = solver.solve_and_return_solution(image)
        if captcha_text != 0:
            print("captcha text [" + captcha_text + "]")
        else:
            print("task finished with error " + solver.error_code)
        return captcha_text

    def check_captcha(self, email, password, emailh):
        # 检查并处理验证码
        ca = '' 
        try:
            ca = self.driver.find_element(By.ID, "captchaimg").accessible_name
        except Exception as e:
            None
        if ca != '':
                print("captcha detected")
                try:
                    picture_name = email + "_captcha" + '.jpeg'
                    WebDriverWait(self.driver, 10, 0.5).until(lambda el: self.driver.find_element(By.ID, 'captchaimg'))
                    self.driver.find_element(By.ID, 'captchaimg').screenshot(picture_name)
                    captcha_code = self.get_captcha_code(picture_name)
                    if os.path.exists(picture_name) and captcha_code != "":
                        os.remove(picture_name)
                        print(f"{picture_name} has been deleted")
                    else:
                        print(f"{picture_name} does not exist")
                    
                    self.driver.find_element(By.CSS_SELECTOR, "input[type=text]").send_keys(captcha_code)
                    print(f"{picture_name} check_captcha 1")
                    #self.driver.find_element(By.XPATH, "//*[@id=\"identifierNext\"]/div/button/span").click()
                    next_button = WebDriverWait(self.driver, 10).until(
                        EC.element_to_be_clickable((By.ID, "identifierNext"))
                    )
                    next_button.click()
                    self.log_step("验证下一步按钮", email, save_screenshot=True)

                    print(f"{picture_name} check_captcha 2")
                    WebDriverWait(self.driver, 10).until(EC.visibility_of_element_located((By.ID, 'password')))
                    print(f"{picture_name} check_captcha 3")
                    time.sleep(7)
                    self.driver.save_screenshot('/root/tmp/gmail_error/' + email + "_after_captcha_1_" + str(time.time()) + ".png")
                    print(f"{picture_name} check_captcha 4")

                    self.driver.find_element(By.CSS_SELECTOR, "input[type=password]").send_keys(password)
                    self.log_step("验证区输入密码", email, save_screenshot=True)
                    print(f"{picture_name} check_captcha 5")
                    WebDriverWait(self.driver, 20).until(EC.visibility_of_element_located((By.ID, 'passwordNext')))
                    print(f"{picture_name} check_captcha 6")
                    time.sleep(3)
                    self.driver.save_screenshot('/root/tmp/gmail_error/' + email + "_after_captcha_2_" + str(time.time()) + ".png")
                    print(f"{picture_name} check_captcha 7")

                    self.driver.find_element(By.ID, "passwordNext").click()
                    print(f"{picture_name} check_captcha 8")
                    try:
                        print("Waiting for final element after captcha...")
                        WebDriverWait(self.driver, 30).until(lambda d: d.execute_script('return document.readyState') == 'complete')
                        print("Page loaded. Current URL:", self.driver.current_url)
                        
                        final_element = WebDriverWait(self.driver, 20).until(
                            EC.visibility_of_element_located((By.XPATH, '//*[@id="view_container"]/div/div/div[2]/div/div[1]/div/form/span/section/header/figure/div/p'))
                        )
                        print("Final element found:", final_element.text)
                    except TimeoutException:
                        print("Timeout waiting for final element. Current URL:", self.driver.current_url)
                        print("Page source:", self.driver.page_source[:1000])  # 打印前1000个字符
                        self.driver.save_screenshot('/root/tmp/gmail_error/timeout_after_captcha_' + email + " " + str(time.time()) + '.png')
                    except Exception as e:
                        print("Unexpected error:", str(e))
                        self.driver.save_screenshot('/root/tmp/gmail_error/error_after_captcha_' + email + " " + str(time.time()) + '.png')

                except TimeoutException:
                    print("captcha exception")
                    print("Element not found after captcha. Current URL:", self.driver.current_url)
                    print("Page source:", self.driver.page_source)
                    

    def check_for_solutions(self):
            # 检查是否有解决方案
            if self.driver.current_url.startswith("https://accounts.google.com/signin/oauth/consent?"):
                print("trying that method")
                for i in range(1,20):
                    try:
                    # 获取 HTML网页源码

                        pageSource = self.driver.page_source
                        a = extract_credential_response(pageSource)
                        if a:
                            print("$RESULT$:", a)
                    except:
                        time.sleep(0.5)
                        print("exception")
                        pass
                    else:
                        exit()



            delete = []
            for i in range(0, len(reqids)): 
                aid = reqids[i]
                try:
                    body = self.driver.execute_cdp_cmd('Network.getResponseBody', {'requestId': aid})['body']
                    delete.append(aid)
                    #print(body)
                    print("?code=" in body)
                    if "?code=" in body:
                        print("$RESULT$:", body)
                        exit()
                    a = extract_credential_response(body)
                    if a:
                        print("$RESULT$:", body)
                        exit()
                except Exception as e:
                    #print("not yet " + str(e))
                    pass
            result = [x for x in reqids if not(x in delete)] 
            
    def registration_process(self, start_url, email, password, recovery_email, world_name_int, server_identifier=None):
        """主要的注册流程"""

        print("开始注册流程")
        self.log_step("开始注册流程", email)
        retry_count = 0
        max_retries = 20
        
        # 访问初始页面
        self.driver.get(start_url)
        time.sleep(6)
        
        # 截取屏幕截图
        # screenshot_path = 'kakaogames.png'
        # driver.save_screenshot(screenshot_path)
        # print(f"屏幕截图已保存至: {screenshot_path}")

        while retry_count < max_retries:
            retry_count += 1
            print(f"当前步骤: {self.step}, 尝试次数: {retry_count}")
            #去掉应该可以使用
            #self.check_for_solutions()
            # 等待一下网络延迟
            if time.time() - self.lastload < 5:
                retry_count -= 1
                print("等待网络延迟...")
                time.sleep(5)
                continue

            #处理验证码
            self.check_captcha(email, password, "emailh")
            #判断是选择对号 还是到了选择区和服务器
            self.check_step(email)

            # 根据当前步骤执行对应操作
            if self.step == "start":
                self.click_google_login()
            elif self.step == "err_exit":
                self.log_step("代理不可用退出", email,)
                return False
            elif self.step == "input_email":
                self.input_email(email)
            elif self.step == "input_password":
                self.input_password(email, password)
            elif self.step == "click_continue":
                self.click_continue_by_xpath(email)
            elif self.step == "confirm_terms":
                self.confirm_terms_of_service(email)
            elif self.step == "accept_agreements":
                self.accept_agreements(email)
            elif self.step == "select_account":
                self.select_account(email)
            elif self.step == "select_world":
                self.select_world(email, world_name_int, server_identifier )
            elif self.step == "input_character_name":
                self.input_character_name(email)
            elif self.step == "complete":
                print("注册流程已完成!")
                self.log_step("注册成功", email, save_screenshot=True)
                return True
                
            time.sleep(2)  # 每次循环间隔
            
        self.log_step("达到最大重试次数，注册失败", email, save_screenshot=True)
        return False

    def extract_part(self, message):
        """使用partition方法提取"""
        return message.partition(':')[0]

    def log_step(self, message, email="", save_screenshot=False):
        """记录步骤信息并可选保存截图"""

        logging.info(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {email} {message}")

        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {message}")
        print(f"当前标题: {self.driver.title}")
        print(f"当前URL: {self.driver.current_url}")
        action_name = self.extract_part(message)
        
        
        if save_screenshot and hasattr(self, 'driver'):
            try:
                # 确保email有效且不包含特殊字符
                safe_email = "unknown" if not email else email.split("@")[0].replace(".", "_")
                timestamp = str(int(time.time()))  # 使用整数时间戳
                
                
                # 创建安全的文件名
                filename = f"{safe_email}_{action_name}_{timestamp}.png"
                screenshot_path = f"/root/tmp/{filename}"
                
                # 确保目录存在
                os.makedirs("/root/tmp", exist_ok=True)
                
                # 保存截图
                self.driver.save_screenshot(screenshot_path)
                print(f"截图已保存至: {screenshot_path}")
            except Exception as e:
                print(f"保存截图失败: {str(e)}")

    
    def click_google_login(self):
        """基于JavaScript逻辑实现的精确点击方法"""
        try:
            self.log_step("开始执行Google登录流程")

        # # 先检查是否已经处于目标页面
        #     if "accounts.google.com" in self.driver.current_url.lower():
        #         self.log_step("检测到已在Google登录页面，跳过点击直接进入下一步")
        #         self.step = "input_email"
        #         self.lastload = time.time()
        #         return True
                
            # 先检查是否已经处于密码输入页面
            if self.driver.current_url.startswith("https://accounts.google.com/v3/signin/identifier?"):
                self.log_step("检测到协议页面")
                self.step = "input_email"
                self.lastload = time.time()
                return True

            # ... [初始化登录过程]
            self.driver.add_cdp_listener("Network.requestWillBeSentExtraInfo", mylousyprintfunction)
            self.driver.add_cdp_listener('Network.requestWillBeSent', mylousyprintfunction)

            # 1. 等待并获取第一个ul元素
            ul_element = WebDriverWait(self.driver, 15).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "ul.list_account"))
            )
            self.log_step("找到账户列表UL元素")

            # 2. 获取第一个li元素
            first_li = ul_element.find_element(By.CSS_SELECTOR, "li:first-child")
            self.log_step("找到第一个LI元素")

            # 3. 查找可点击元素（支持多种类型）
            click_target = first_li.find_element(
                By.CSS_SELECTOR, "a, button, [onclick], [role='button']"
            )
            self.log_step(f"找到可点击元素：{click_target.tag_name}")

            # 4. 滚动到元素可见位置
            self.driver.execute_script(
                "arguments[0].scrollIntoView({block: 'center', behavior: 'smooth'});",
                click_target
            )
            time.sleep(0.5)  # 等待滚动动画

            # 5. 使用两种点击方式确保成功
            try:
                # 常规点击尝试
                click_target.click()
                self.log_step("常规点击成功")
            except:
                # 失败时使用JavaScript点击
                self.driver.execute_script(
                    "arguments[0].dispatchEvent(new MouseEvent('click', {bubbles: true}));",
                    click_target
                )
                self.log_step("JavaScript点击成功")

            # 6. 验证跳转结果
                # 6. 改进的验证跳转结果逻辑
            try:
                WebDriverWait(self.driver, 45).until(
                    lambda d: "accounts.google.com" in d.current_url.lower()  # 改为小写比较
                )
                self.log_step("成功跳转到Google登录页面")
                
                # 处理可能的弹窗或新窗口
                if len(self.driver.window_handles) > 1:
                    self.driver.switch_to.window(self.driver.window_handles[-1])
                    self.log_step("已切换到新登录窗口")

                self.step = "input_email"
                self.lastload = time.time()
                return True
                
            except Exception as e:
                # 检查当前URL是否已经是Google登录页
                if "accounts.google.com" in self.driver.current_url.lower():
                    self.log_step("已在Google登录页面（验证超时但已跳转）")
                    self.step = "input_email"
                    self.lastload = time.time()
                    return True
                raise  # 重新抛出异常

        except Exception as e:
            error_msg = f"登录流程失败: {str(e)}"
            self.log_step(error_msg, "", save_screenshot=True)
            
            # 如果实际已跳转但误报失败
            if "accounts.google.com" in self.driver.current_url.lower():
                self.log_step("检测到实际已跳转到Google登录页面，修正状态")
                self.step = "input_email"
                self.lastload = time.time()
                return True
                
        return False
            

    def input_email(self, email):
        """输入邮箱"""
        try:
            # 先检查是否已经处于密码输入页面
            if "challenge/pwd" in self.driver.current_url:
                self.log_step("检测到已在密码输入页面，跳过邮箱输入步骤")
                self.step = "input_password"
                self.lastload = time.time()
                return True
                        # 先检查是否已经处于密码输入页面
            if self.driver.current_url.startswith("https://accounts.google.com/speedbump/gaplustos?"):
                self.log_step("检测到协议页面，跳过邮箱输入步骤")
                self.step = "confirm_terms"
                self.lastload = time.time()
                return True

            self.log_step(f"尝试输入邮箱: {email}")
            
            # 等待邮箱输入框出现
            WebDriverWait(self.driver, 20).until(
                EC.visibility_of_element_located((By.ID, "identifierId"))
            )
            
            # 输入邮箱
            email_input = self.driver.find_element(By.ID, "identifierId")
            email_input.clear()
            email_input.send_keys(email)
            self.log_step("已输入邮箱", email, save_screenshot=True)
            
            # 点击下一步
            next_button = WebDriverWait(self.driver, 10).until(
                EC.element_to_be_clickable((By.ID, "identifierNext"))
            )
            next_button.click()
            self.log_step("已点击下一步按钮")

            # 等待页面加载
            print("等待 9 秒，让页面加载...")
            time.sleep(9)

            # 等待密码输入框出现
            WebDriverWait(self.driver, 20).until(
                EC.visibility_of_element_located((By.CSS_SELECTOR, "input[type=password]"))
            )

            print("密码输入框已出现")
            self.step = "input_password"
            self.lastload = time.time()
            
        except Exception as e:
            self.log_step(f"输入邮箱时出错: {str(e)}", email, save_screenshot=True)

    def input_password(self, email, password):
        """输入密码（优化版）"""
        try:
            if self.driver.current_url.startswith("https://accounts.google.com/signin/oauth/id?"):
                self.log_step("检测到已在继续页面")
                self.step = "click_continue"
                self.lastload = time.time()
                return True

            self.log_step("开始密码输入流程", password)
            
            # 1. 等待密码输入框出现（增加更灵活的定位方式）
            password_input = WebDriverWait(self.driver, 20).until(
                EC.visibility_of_element_located(
                    (By.CSS_SELECTOR, "input[type='password'], input[name='password']")
                )
            )
            
            # 2. 输入密码（增加清除和重试机制）
            for _ in range(3):
                password_input.clear()
                password_input.send_keys(password)
                if password_input.get_attribute("value"):
                    break
                time.sleep(0.5)
            self.log_step("密码输入完成", email, save_screenshot=True)
            
            # 3. 点击下一步（多种定位方式尝试）
            next_selectors = [
                "#passwordNext",  # 常规选择器
                "button:contains('Next')",  # 文本匹配
                "div[role='button'][aria-label*='Next']"  # ARIA属性
            ]
            
            for selector in next_selectors:
                try:
                    next_button = WebDriverWait(self.driver, 5).until(
                        EC.element_to_be_clickable((By.CSS_SELECTOR, selector))
                    )
                    next_button.click()
                    self.log_step("下一步按钮点击成功", email, save_screenshot=True)
                    break
                except:
                    continue
            else:
                raise Exception("所有下一步按钮定位方式均失败")

            # 4. 智能等待页面跳转（多重条件判断）
            def is_redirected(driver):
                current_url = driver.current_url.lower()
                return (                    
                    driver.current_url.startswith("https://accounts.google.com/signin/oauth/id?") or
                    driver.current_url.startswith("https://accounts.google.com/speedbump/gaplustos?") or
                    driver.current_url.startswith("https://accounts.google.com/signin/oauth/consent?") or
                    driver.current_url.startswith("https://web-data-cdn.kakaogames.com/tube/live/agreement/index.html") or #选择参数
                    driver.current_url.startswith("https://accounts.google.com/o/oauth2/auth/oauthchooseaccount?") or
                    driver.current_url.startswith("https://pre.kakaogames.com/reservation/login") or #在跳转中
                    "signin/oauth/id" in current_url or  # 点击继续
                    "speedbump/gaplustos" in current_url or  # 服务条款
                    "signin/oauth/consent" in current_url or  # 权限确认
                    "agreement/index.html" in current_url or  # 条款页面
                    "oauthchooseaccount" in current_url or  # 账户选择
                    not any(x in current_url for x in ["signin", "password"])  # 已退出登录流程
                )
            
            try:
                WebDriverWait(self.driver, 15).until(is_redirected)
            except TimeoutException:
                # 最终状态检查（可能已跳转但未触发条件）
                if is_redirected(self.driver):
                    self.log_step("最终检查发现页面已跳转")
                else:
                    self.log_step("警告：页面可能未正确跳转", email, save_screenshot=True)
                    raise Exception("密码提交后页面未跳转")

            # 5. 处理各种可能的跳转结果
            current_url = self.driver.current_url.lower()
            
            if "oauth/id" in current_url:
                self.log_step("检测到登录成功继续")
                self.step = "click_continue"

            elif "reservation/login" in current_url:
                self.log_step("等待跳转游戏网址")
                self.step = "wait"
                
            elif "speedbump/gaplustos" in current_url:
                self.log_step("检测到服务条款确认页面")
                self.step = "confirm_terms"
                
            elif "signin/oauth/consent" in current_url:
                self.log_step("检测到权限确认页面")
                try:
                    continue_btn = WebDriverWait(self.driver, 10).until(
                        EC.element_to_be_clickable((By.CSS_SELECTOR, "button[jsname='LgbsSe']")))
                    continue_btn.click()
                    self.log_step("已点击继续按钮")
                    time.sleep(2)  # 等待页面反应
                except:
                    self.log_step("权限确认页面操作失败", email, save_screenshot=True)
                    
            elif "agreement/index.html" in current_url:
                self.log_step("已跳转到条款页面")
                self.step = "confirm_terms"
                
            elif "oauthchooseaccount" in current_url:
                self.log_step("检测到账户选择页面")
                self.step = "select_account"
                
            else:
                self.log_step("未知的跳转状态", email, save_screenshot=True)
                raise Exception(f"未知的跳转目标: {current_url}")
                
            self.lastload = time.time()
            return True
            
        except Exception as e:
            error_msg = f"密码输入流程出错: {str(e)}"
            self.log_step(error_msg, email, save_screenshot=True)
            
            # 检查常见错误情况
            if "invalid password" in str(e).lower():
                self.step = "input_email"  # 返回邮箱输入步骤
            elif "try again" in str(e).lower():
                self.step = "input_password"  # 重试密码输入
                
            return False



    def click_continue_by_xpath(self, email):
        """
        使用XPath定位并点击Continue按钮
        (基于多层嵌套结构中包含"Continue"文本的span元素)
        
        参数:
            driver: WebDriver实例
            timeout: 等待超时时间(秒)
            
        返回:
            bool: 是否点击成功
        """
        try:
            driver = self.driver
            if not self.driver.current_url.startswith("https://accounts.google.com/signin/oauth/id?authuser=0"):
                return False

            self.log_step("Continue按钮", email)
            # XPath定位策略
            xpath = '//button[.//span[text()="Continue"]]'
            
            # 等待元素可点击
            continue_button = WebDriverWait(driver, 10).until(
                EC.element_to_be_clickable((By.XPATH, xpath)))
            
            # 滚动到元素可见
            driver.execute_script(
                "arguments[0].scrollIntoView({block: 'center', behavior: 'smooth'});", 
                continue_button
            )
            time.sleep(0.5)  # 等待滚动完成
            
            # 使用JavaScript点击确保可靠性
            driver.execute_script("arguments[0].click();", continue_button)
            
            print("通过XPath成功点击Continue按钮")
            self.step = "accept_agreements"
            print("等待 15 秒，让页面加载KAKAO...")
            time.sleep(15)
            self.lastload = time.time()
            return True
            
        except TimeoutException:
            print(f"错误：{timeout}秒内未找到Continue按钮 (XPath: {xpath})")
        except Exception as e:
            print(f"点击时发生意外错误: {str(e)}")
            self.log_step("点击时发生意外错误", email, save_screenshot=True)
   
            return False      

    def confirm_terms_of_service(self, email):
        """确认服务条款（优化滚动和点击逻辑）"""
        try:
            current_url = self.driver.current_url
            self.log_step("开始处理服务条款确认流程", email)
            
            # 处理Google服务条款页面
            if "speedbump/gaplustos" in current_url:
                self.log_step("在Google服务条款页面")
                
                # 尝试多种按钮定位方式
                button_selectors = [
                    "#confirm",  # 首选ID
                    "#accept",    # 备选ID
                    "button[aria-label*='同意']",  # 中文按钮
                    "button:contains('Accept')",  # 英文按钮
                    "button:contains('同意')"     # 中文按钮
                ]
                
                confirm_button = None
                for selector in button_selectors:
                    try:
                        elements = self.driver.find_elements(By.CSS_SELECTOR, selector)
                        if elements and elements[0].is_displayed():
                            confirm_button = elements[0]
                            break
                    except:
                        continue
                
                if confirm_button:
                    # 滚动到按钮可见（增强版滚动）
                    self.driver.execute_script(
                        "arguments[0].scrollIntoView({"
                        "behavior: 'smooth', "
                        "block: 'center', "
                        "inline: 'center'"
                        "});", 
                        confirm_button
                    )
                    time.sleep(1)  # 等待滚动完成
                    self.log_step("服务条款开始点击", email, save_screenshot=True)
                    # 尝试多种点击方式
                    for click_method in [
                        lambda: confirm_button.click(),
                        lambda: self.driver.execute_script("arguments[0].click();", confirm_button),
                        lambda: confirm_button.send_keys(Keys.RETURN)
                    ]:
                        try:
                            click_method()

                            time.sleep(1)  # 等待滚动完成
                            if "signin/oauth/id" in self.driver.current_url:
                                self.step = "click_continue"
                              
                            self.log_step("服务条款确认按钮点击成功", email, save_screenshot=True)
                            break
                        except:
                            continue
                    else:
                        raise Exception("所有点击方式均失败")
                    
                    time.sleep(5)  # 等待页面反应

            # 处理Odin游戏条款页面
            elif "agreement/index.html" in current_url:
                self.log_step("在Odin游戏条款页面")
                
                # 滚动到页面底部（确保条款内容加载）
                self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight)")
                time.sleep(2)
                
                # 等待并勾选"同意所有"选项
                agree_all = WebDriverWait(self.driver, 30).until(
                    EC.presence_of_element_located((By.ID, "checkAgreeAll"))
                )
                
                # 如果元素不在视窗内，再次滚动
                if not agree_all.is_displayed():
                    self.driver.execute_script(
                        "arguments[0].scrollIntoView({block: 'center'});",
                        agree_all
                    )
                    time.sleep(1)
                
                if not agree_all.is_selected():
                    agree_all.click()
                    self.log_step("已勾选'同意所有'选项", email, save_screenshot=True)
                
                # 处理继续按钮
                continue_button = WebDriverWait(self.driver, 15).until(
                    EC.element_to_be_clickable((By.CSS_SELECTOR, "button.agree__btn--continue"))
                )
                
                # 确保按钮可见
                self.driver.execute_script(
                    "arguments[0].scrollIntoViewIfNeeded();", 
                    continue_button
                )
                time.sleep(0.5)
                
                continue_button.click()
                self.log_step("已点击继续按钮", email, save_screenshot=True)
                time.sleep(3)

            # 检查后续跳转
            current_url = self.driver.current_url.lower()
            if "oauthchooseaccount" in current_url:
                self.step = "select_account"
            elif "/server" in current_url:
                self.step = "select_world"
            else:
                self.step = "unknown"
                
            self.lastload = time.time()
            return True
            
        except Exception as e:
            error_msg = f"服务条款确认失败: {str(e)}"
            self.log_step(error_msg, email, save_screenshot=True)
            return False
            
    def confirm_terms_of_service11(self, email):
        """确认服务条款"""
        try:
            current_url = self.driver.current_url
            self.log_step("尝试确认服务条款")
            
            # 处理Google服务条款页面
            if "speedbump/gaplustos" in current_url:
                self.log_step("在Google服务条款页面")
                
                # 寻找确认按钮
                confirm_button = None
                if self.driver.find_elements(By.ID, "confirm"):
                    confirm_button = self.driver.find_element(By.ID, "confirm")
                elif self.driver.find_elements(By.ID, "accept"):
                    confirm_button = self.driver.find_element(By.ID, "accept")
                elif self.driver.find_elements(By.TAG_NAME, "button"):
                    confirm_button = self.driver.find_element(By.TAG_NAME, "button")
                    
                if confirm_button:
                    confirm_button.click()
                    self.log_step("已点击确认按钮")
                    time.sleep(5)
                    
                    # 检查是否需要点击继续
                    if "signin/oauth/id" in self.driver.current_url:
                        continue_button = self.driver.find_elements(By.CSS_SELECTOR, "button[jsname='LgbsSe']")
                        if continue_button:
                            continue_button[-1].click()
                            self.log_step("已点击继续按钮")
                    
                    time.sleep(5)
                    
            # 处理Odin游戏条款页面
            elif "agreement/index.html" in current_url:
                self.log_step("在Odin游戏条款页面")
                
                # 等待条款勾选框出现
                WebDriverWait(self.driver, 30).until(
                    EC.presence_of_element_located((By.ID, "checkAgreeAll"))
                )
                
                # 勾选"同意所有"选项
                agree_all = self.driver.find_element(By.ID, "checkAgreeAll")
                if not agree_all.is_selected():
                    agree_all.click()
                    self.log_step("已勾选'同意所有'选项")
                
                # 点击继续按钮
                WebDriverWait(self.driver, 10).until(
                    EC.element_to_be_clickable((By.CSS_SELECTOR, "button.agree__btn--continue"))
                )
                continue_button = self.driver.find_element(By.CSS_SELECTOR, "button.agree__btn--continue")
                continue_button.click()
                self.log_step("已点击继续按钮")
                
                time.sleep(5)
                
                # 如果跳转到了账户选择页面
                if "oauthchooseaccount" in self.driver.current_url:
                    self.step = "select_account"
                    return
                
            # 检查是否跳转到服务器选择页面
            if "/server" in self.driver.current_url:
                self.log_step("已跳转到服务器选择页面")
                self.step = "select_world"
                return
                
            self.lastload = time.time()
            
        except Exception as e:
            self.log_step(f"确认服务条款时出错: {str(e)}", email, save_screenshot=True)

    def select_account(self, email):
        """选择已登录的账户"""
        try:
            self.log_step("尝试选择已登录的账户")
            
            # 等待账户列表出现
            WebDriverWait(self.driver, 20).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "div[role='link'][data-identifier]"))
            )
            
            # 选择第一个账户
            account = self.driver.find_element(By.CSS_SELECTOR, "div[role='link'][data-identifier]")
            account.click()
            self.log_step("已选择账户")
            
            time.sleep(5)
            
            # 检查是否跳转到服务器选择页面
            if "/server" in self.driver.current_url:
                self.log_step("已跳转到服务器选择页面")
                self.step = "select_world"
                return
                
            self.lastload = time.time()
            
        except Exception as e:
            self.log_step(f"选择账户时出错: {str(e)}", email, save_screenshot=True)

    def click_continue_button(self, email):
        """点击Continue按钮"""
        try:
            driver = self.driver
            self.log_step("点击参数Continue按钮")
            # 通过CSS类名定位Continue按钮
            continue_btn = WebDriverWait(driver, 10).until(
                EC.element_to_be_clickable((By.CSS_SELECTOR, "button.agree__btn--continue")))
            
            # 滚动到按钮可见
            driver.execute_script("arguments[0].scrollIntoView();", continue_btn)
            
            # 使用JavaScript点击（避免遮挡问题）
            driver.execute_script("arguments[0].click();", continue_btn)
            print("Continue按钮点击成功")
            self.lastload = time.time()
            return True
            
        except Exception as e:
             
            self.log_step(f"点击Continue按钮失败: {str(e)}", email, save_screenshot=True)
            return False
            
    def accept_agreements(self, email):
        """
        自动接受所有条款协议
        适用于：https://web-data-cdn.kakaogames.com/tube/live/agreement/index.html
        """
        target_url = "https://web-data-cdn.kakaogames.com/tube/live/agreement/index.html"
        driver = self.driver
        try:
            if not driver.current_url.startswith(target_url):
                return False

            self.log_step("自动接受所有条款协议")
            # 等待页面完全加载
            WebDriverWait(driver, 20).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, ".terms__wrap")))
            
            # 方法1：直接点击"Agree to all"主选项
            try:
                agree_all = WebDriverWait(driver, 10).until(
                    EC.element_to_be_clickable((By.ID, "checkAgreeAll")))
                
                # 滚动到元素可见
                driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", agree_all)
                time.sleep(0.5)
                
                # 确保元素可点击
                driver.execute_script("arguments[0].click();", agree_all)
                print("成功点击'Agree to all'主选项")

                self.click_continue_button(email)

                self.step = "select_world"

                return True
            except:
                print("主选项点击失败，尝试逐个选择")

            # 方法2：逐个选择所有必选项（备用方案）
            required_checks = driver.find_elements(
                By.CSS_SELECTOR, 
                ".terms-list input[type='checkbox'][id^='checkAgree']")
            
            for checkbox in required_checks:
                try:
                    if not checkbox.is_selected():
                        driver.execute_script("arguments[0].scrollIntoViewIfNeeded();", checkbox)
                        driver.execute_script("arguments[0].click();", checkbox)
                        time.sleep(0.3)
                except Exception as e:
                    print(f"选择条款时出错: {str(e)}")
                    continue

            # 验证是否全部选中
            all_checked = all(checkbox.is_selected() for checkbox in required_checks)
            if not all_checked:
                raise Exception("仍有未选中的必选条款")

            print("所有条款已同意")
            return True

        except Exception as e: 
            self.log_step(f"接受条款失败: {str(e)}", email, save_screenshot=True)
            return False

    def check_step(self, email):
        try:
            if self.driver.current_url.startswith("https://web-data-cdn.kakaogames.com/tube/live/agreement/index.html?"):
                self.step = "accept_agreements"
                return True

            elif self.driver.current_url.startswith("https://pre.kakaogames.com/odinvalhallarising/reservation/6/server"):
                self.step = "select_world"
                return True

            elif self.driver.current_url.startswith("https://pre.kakaogames.com/odinvalhallarising/reservation/6/character"):
                self.step = "input_character_name"
                return True

            elif self.driver.current_url.startswith("https://accounts.google.com/signin/oauth/id?"):
                self.step = "click_continue"
                return True

            elif self.driver.current_url.startswith("https://pre.kakaogames.com/reservation/login"):
                self.step = "wait"
                print("等待 4 秒，让页面跳转...")
                time.sleep(4)
                return False
            elif self.driver.current_url.startswith("https://pre.kakaogames.com/odinvalhallarising/reservation/6/complete"):
                self.step = "complete"
                print("检测到完成页面")               
                return False
            elif self.driver.current_url.startswith("https://pre.kakaogames.com/reservation/error"):
                print("代理不可用1")
                self.step = "err_exit"
                return False
            elif self.driver.current_url.startswith("https://accounts.google.com/o/oauth2/auth"):
                print("代理不可用2")
                self.step = "err_exit"
                return False

        except Exception as e:
            print(f"check_step: {str(e)}")
             
    def click_next_button(self, email, timeout=10):
        """
        点击页面底部的Next按钮
        
        参数:
            driver: WebDriver实例
            timeout: 元素等待超时时间(秒)
        """
        self.log_step("点击Next")
        try:
            driver = self.driver
            # 等待按钮可点击
            next_btn = WebDriverWait(driver, timeout).until(
                EC.element_to_be_clickable((By.CSS_SELECTOR, "button.btn_next"))
            )
            
            #driver.execute_script("arguments[0].scrollIntoView({block: 'end'});", next_btn)
            # 滚动到页面底部（确保按钮可见）
            driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(0.5)  # 等待滚动完成
            
            # 使用JavaScript点击（避免被其他元素遮挡）
            driver.execute_script("arguments[0].click();", next_btn)
            print("Next按钮点击成功")
            
            return True
            
        
        except Exception as e:            
            self.log_step(f"点击时发生错误: {str(e)}", email, save_screenshot=True)
        return False

    def select_world(self, email, world_name_int, server_identifier=None, timeout=10):
        """
        选择游戏世界（支持按名称选择或默认选择当前选中项）
        
        参数:
            driver: WebDriver实例
            world_name: 要选择的世界名称（如"Vanaheim"或"Asgard"），None则保持当前选中
            timeout: 元素等待超时时间(秒)
        """
 
        try:
            
            world_name_list = ["Vanaheim", "Asgard"]
            world_name = world_name_list[int(world_name_int)]

            print(f"选择世界: {self.driver.current_url}")
            self.log_step(f"选择游戏世界_[{world_name}]_[{server_identifier}]")

            if self.driver.current_url.startswith("https://pre.kakaogames.com/odinvalhallarising/reservation/6/character"):
                print("无需等待，以在输入名称页面")                 
                return False

            if not self.driver.current_url.startswith("https://pre.kakaogames.com/odinvalhallarising/reservation/6/server"):
                print("等待 5.5 秒，等页面跳转...")
                time.sleep(5)
                self.lastload = time.time()
                return False



            self.lastload = time.time()
            driver = self.driver
            # 1. 展开世界选择列表
            self.log_step("展开世界选择列表")
            toggle = WebDriverWait(driver, timeout).until(
                EC.element_to_be_clickable((By.CSS_SELECTOR, ".link_selected")))
            
            # 确保元素可见
            driver.execute_script("arguments[0].scrollIntoViewIfNeeded();", toggle)
            
            # 点击展开（如果未展开）
            if "on" not in toggle.get_attribute("class"):
                toggle.click()
                time.sleep(0.5)  # 等待动画

            # 2. 选择目标世界
            if world_name:
                # 方法1：精确文本匹配
                xpath = f"//a[contains(@class, 'link_world') and contains(., '{world_name}')]"
                target = WebDriverWait(driver, timeout).until(
                    EC.element_to_be_clickable((By.XPATH, xpath)))
            else:
                # 方法2：选择当前已选中的（通过aria-selected属性）
                target = WebDriverWait(driver, timeout).until(
                    EC.element_to_be_clickable((By.CSS_SELECTOR, ".link_world[aria-selected='true']")))

            # 3. 执行点击
            driver.execute_script("arguments[0].click();", target)

            print(f"成功选择世界: {target.text.strip()}")

            #选择大区和服务器
            self.select_server(email, server_identifier)

            #点击NEXT
            self.click_next_button(email)

            self.log_step("已点击Next")
            
            print("等待页面跳转到角色名称输入页面")
            try:
                WebDriverWait(self.driver, 10).until(
                    lambda driver: "reservation/6/character" in driver.current_url
                )
                self.log_step("已跳转到角色名称输入页面")
                self.step = "input_character_name"
                return
            except:
                print("等待超时，未跳转到角色名称页面")
 

            self.lastload = time.time()
            #self.log_step(f"世界选项完成", email, save_screenshot=True)
            return True
 
        except Exception as e:
            print(f"选择游戏世界URL: {self.driver.current_url}")
            self.log_step(f"选择游戏世界: {str(e)}", email, save_screenshot=True)
    
            return False

    def select_server(self, email, server_identifier=None, timeout=10):
        """
        选择游戏服务器（支持按名称或索引选择）
        
        参数:
            driver: WebDriver实例
            server_identifier: 
                - 数字类型: 按索引选择 (从1开始)
                - 字符串类型: 按服务器名称匹配 (如"Asgard 03")
                - None: 选择第一个可用服务器
            timeout: 元素等待超时时间(秒)
        """
        try:
            driver = self.driver
            self.log_step("尝试选择服务器")
            # 等待服务器列表加载
            server_list = WebDriverWait(driver, timeout).until(
                EC.presence_of_element_located((By.CSS_SELECTOR, "ul.list_server")))
            
            # 获取所有服务器选项
            servers = server_list.find_elements(By.CSS_SELECTOR, "li a.link_server")
            if not servers:
                raise NoSuchElementException("未找到可用服务器")

            # 确定目标服务器
            target = None
            if server_identifier is None:
                target = servers[0]  # 默认选第一个
            elif isinstance(server_identifier, int):
                if 1 <= server_identifier <= len(servers):
                    target = servers[server_identifier - 1]
                else:
                    raise ValueError(f"服务器索引超出范围 (1-{len(servers)})")
            elif isinstance(server_identifier, str):
                target = next(
                    (s for s in servers if server_identifier in s.text),
                    None
                )
                if not target:
                    available = [s.text for s in servers]
                    raise NoSuchElementException(
                        f"未找到包含 '{server_identifier}' 的服务器，可用服务器: {available}")

            # 执行选择操作
            driver.execute_script("arguments[0].scrollIntoView({block: 'center'});", target)
            time.sleep(0.3)  # 等待滚动
            
            # 先检查是否可选
            if target.get_attribute("aria-disabled") == "true":
                raise ValueError(f"服务器 {target.text} 不可选")
                
            target.click()
            print(f"已选择服务器: [{target.text.strip()}]")

            self.log_step(f"已选择服务器", email, save_screenshot=True)

            return True

        
        except Exception as e:            
            self.log_step(f"选择失败: {str(e)}", email, save_screenshot=True)
            return False
     

    def generate_random_string(self):
        # 确定字符串长度 (2-12)
        length = random.randint(2, 12)
        
        # 确保至少有一个字母
        first_char = random.choice(string.ascii_letters)
        
        # 剩余字符可以是字母或数字
        remaining_chars = ''.join(random.choice(string.ascii_letters + string.digits) for _ in range(length - 1))
        
        # 组合成最终字符串
        random_string = first_char + remaining_chars
        
        return random_string

    def input_character_name(self, email):
        """输入角色名称"""
        try:
            self.log_step("尝试输入角色名称")
            # 提取 @ 前面的部分
            #character_name = email.split("@")[0] + str(random.randint(100, 999))  # "64sdsfdd"
            character_name = self.generate_random_string()
            self.log_step(f"生成名称: {character_name}")
            
            # 滚动到页面顶部（确保按钮可见）
            driver.execute_script("window.scrollTo(0, 0);")
            time.sleep(0.5)  # 等待滚动完成

            # 等待名称输入框出现
            WebDriverWait(self.driver, 20).until(
                EC.visibility_of_element_located((By.ID, "tfCharacter"))
            )
            
            # 输入角色名称
            name_input = self.driver.find_element(By.ID, "tfCharacter")
            name_input.clear()
            name_input.send_keys(character_name)
            self.log_step("已输入角色名称")
            
            # 点击验证按钮
            verify_button = self.driver.find_element(By.CSS_SELECTOR, "a.link_verify")
            verify_button.click()
            self.log_step("已点击验证按钮")
            
            time.sleep(3)
            
            # 检查名称是否可用
            verification_result = self.driver.find_elements(By.CSS_SELECTOR, "p.txt_verify")
            if verification_result and "Available" in verification_result[0].text:
                self.log_step("角色名称可用")
                
                # 勾选同意选项
                agree_checkbox = self.driver.find_element(By.ID, "agreeAll")
                if not agree_checkbox.is_selected():
                    agree_checkbox.click()
                    self.log_step("已勾选同意选项")
                
                # 点击确认按钮
                confirm_button = self.driver.find_element(By.CSS_SELECTOR, "button.btn_confirm")
                confirm_button.click()
                self.log_step("已点击确认按钮")
                
                time.sleep(5)
                
                # 检查是否完成注册
                if "/complete" in self.driver.current_url:
                    self.log_step("注册完成！")
                    self.step = "complete"
                    return
            else:
                # 名称不可用，生成新的名称
                error_msg = self.driver.find_elements(By.CSS_SELECTOR, "div.box_alert")
                if error_msg and "Already in use" in error_msg[0].text:
                    self.log_step("角色名称已被使用，尝试新名称")
                    new_name = character_name + str(random.randint(100, 999))
                    self.input_character_name(new_name)
                    return
                    
            self.lastload = time.time()
            
        except Exception as e:
            self.log_step(f"输入角色名称时出错: {str(e)}", email, save_screenshot=True)

   
    def start(self, url, email, password, recovery_email, proxy, world_name_int, server_identifier=None):
        """启动注册流程"""
        print("开始Odin:Valhalla Rising注册流程")
        warnings.filterwarnings("ignore")
        logging.getLogger("urllib3").setLevel(logging.ERROR)
        
        start_timestamp = int(time.time())
        result = {
            'status': 'failed',
            'email': email,
            'server': world_name_int,
            'region': server_identifier,
            'char_name': "",
            'message': "",
            'error': "",
            'step'
        }

        try:
            self.proxy = proxy
            self.run_chrome(proxy)
            
            print("准备注册")
            success = self.registration_process(url, email, password, recovery_email, world_name_int, server_identifier)
            
            if success:
                result['status'] = 'success'
                # 提取服务器和角色名信息
                info_elements = self.driver.find_elements(By.CSS_SELECTOR, "ul.list_info li p.txt_info")
                if len(info_elements) >= 2:
                    result['step'] = self.step
                    result['server'] = info_elements[0].text
                    result['char_name'] = info_elements[1].text
                    result['message'] = "register_ok"
                else:
                    result['message'] = "register_ok_no_info"
                
                print("$RESULT$:", json.dumps(result))
                print(json.dumps(result))

                return 0
                
            else:
                result['step'] = self.step
                result['error'] = "register_error"
                print("$ERROR$:" , json.dumps(result))
                print(json.dumps(result))
                return 1
                
        except Exception as e:
            error_msg = str(e)
            result['step'] = self.step
            result['error'] = error_msg
            result['message'] = "register_error_ty"
            self.driver.save_screenshot(f'/root/tmp/error_{time.strftime("%Y%m%d_%H%M%S")}.png')
            print(json.dumps(result))
            return 1
            
        finally:
            print(f"总用时: {int(time.time()) - start_timestamp}")
            if self.driver:
                self.driver.quit()

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == "--check-versions":
        check_versions()
    else:
        result = {
            'status': 'failed',
            'step': "",
            'message': '',
            'error': ''
        }
        return_code = 1  # 默认失败状态
        
        try:
            # 参数检查
            if len(sys.argv) < 7:  # 修改为7，因为现在需要6个必要参数
                result['error'] = "参数不足"
                result['message'] = f"需要6个参数，收到 {len(sys.argv)-1} 个\n使用方法: python script.py [url] [email] [password] [recovery_email] [world_name_int] [server_identifier] [proxy_json(可选)]"
                print(json.dumps(result))
                sys.exit(1)
                
            # 参数解析
            url = sys.argv[1]
            email = sys.argv[2]
            password = sys.argv[3]
            recovery_email = sys.argv[4]
            world_name_int = sys.argv[5]
            server_identifier = sys.argv[6]
            proxy = sys.argv[7] if len(sys.argv) > 7 else "{}"
            
            # 打印参数（可选，调试用）
            param_info = {
                'url': url,
                'email': email,
                'recovery_email': recovery_email,
                'world_name_int': world_name_int,
                'server_identifier': server_identifier,
                'proxy': proxy
            }
            print(f"启动参数: {json.dumps(param_info)}")
            
            # Xvfb 初始化
            xvfb = None
            try:
                from xvfbwrapper import Xvfb
                xvfb = Xvfb(width=800, height=600)
                xvfb.start()
            except ImportError:
                print(json.dumps({'status': 'warning', 'message': 'xvfbwrapper 未安装，将直接启动浏览器'}))
            
            # 执行主逻辑
            bot = OdinRegistrationBot()
            return_code = bot.start(url, email, password, recovery_email, proxy, world_name_int, server_identifier)
            
        except Exception as e:
            result['error'] = str(e)
            result['message'] = "主程序异常"
            print(json.dumps(result))
            return_code = 1
            import traceback
            traceback.print_exc()
            
        finally:
            if xvfb:
                xvfb.stop()
                print(json.dumps({'status': 'info', 'message': 'Xvfb已停止'}))
            sys.exit(return_code)  # 确保返回正确的状态码