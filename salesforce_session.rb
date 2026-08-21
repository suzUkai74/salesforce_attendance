require 'selenium-webdriver'

# Salesforce へのログイン・WebDriver の生成・要素操作を担うクラス。
# 勤怠入力・経費精算の各スクリプトから流用する。
# selectors には各画面の要素定義（config.yml の *.selectors）を渡す。
class SalesforceSession
  attr_reader :driver

  def initialize(config, selectors = {})
    @config    = config
    @selectors = selectors
    @driver    = setup_driver
  end

  def login
    @driver.navigate.to(@config['login_url'])
    @driver.find_element(:id, 'username').send_keys(@config['username'])
    @driver.find_element(:id, 'Login').click
    sleep 1 # パスワード入力欄が表示されるまで待つ
    @driver.find_element(:id, 'password').send_keys(@config['password'])
    @driver.find_element(:id, 'Login').click
    wait_until(timeout: 30) { @driver.title.start_with?('Salesforce') }
    puts 'Login success.'
  rescue StandardError
    raise 'Login failed.'
  end

  # ブラウザは chromedriver の終了と同時に閉じてしまうため、
  # 入力結果を確認できるよう Enter が押されるまで待つ。
  def wait_for_user
    puts '入力内容を確認してください。Enter でブラウザを閉じます。'
    $stdin.gets
  end

  def quit
    @driver&.quit
  end

  def find(key)
    how, what = locator(key)
    @driver.find_element(how, what)
  end

  def find_all(key)
    how, what = locator(key)
    @driver.find_elements(how, what)
  end

  def displayed?(key)
    find_all(key).any?(&:displayed?)
  end

  def click(key)
    wait_until { find(key).displayed? }
    element = find(key)
    element.click
  rescue Selenium::WebDriver::Error::ElementClickInterceptedError
    # 何かに覆われている場合は JavaScript でクリックする。
    @driver.execute_script('arguments[0].click();', element)
  end

  # 確認ダイアログが表示されたら OK を押す。一定時間出なければ何もしない。
  def confirm
    wait_until(timeout: 3) { displayed?(:confirm_button) }
    click(:confirm_button)
  rescue Selenium::WebDriver::Error::TimeoutError
    nil # 確認ダイアログが出ないケースもあるため無視する
  end

  # セレクタは 'foo'（id 扱い）または { css: '.foo' } のような形式で設定する。
  def locator(key)
    spec = raw_selector(key)
    spec = { 'id' => spec } if spec.is_a?(String)
    how, what = spec.first
    [how.to_sym, what]
  end

  # config に設定された生の値を返す（id の接頭辞など、直接使いたい場合に利用）。
  def raw_selector(key)
    @selectors.fetch(key.to_s) { raise "config.yml に selectors.#{key} がありません。" }
  end

  def wait_until(timeout: 10, &block)
    Selenium::WebDriver::Wait.new(timeout: timeout).until(&block)
  end

  private

  def setup_driver
    profile_path = @config.fetch('chrome_profile', './chrome_profile')
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--user-data-dir=#{profile_path}")
    Selenium::WebDriver.for(:chrome, options: options)
  end
end
