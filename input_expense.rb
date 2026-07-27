require 'forwardable'
require 'yaml'
require 'active_support/time'
require_relative 'salesforce_session'

# 経費精算（交通費）を締め期間分まとめて入力する。
# 締め期間は「昨月21日 〜 今月20日」。
class ExpenseInputter
  extend Forwardable
  # 要素操作は SalesforceSession に委譲する。
  def_delegators :@session, :find, :find_all, :displayed?, :click, :wait_until

  DEFAULT_DATE_FORMAT = '%Y/%m/%d'.freeze
  DEFAULT_WEEKDAYS    = [1, 3, 5].freeze # 月・水・金

  def initialize(config)
    @config    = config
    @expense   = config.fetch('expense') { raise 'config.yml に expense セクションがありません。' }
    selectors  = @expense.fetch('selectors') { raise 'config.yml に expense.selectors がありません。' }
    @session   = SalesforceSession.new(config, selectors)
    @driver    = @session.driver
  end

  def run(start_date, end_date)
    @session.login
    navigate_to_expense
    input_expenses(target_dates(start_date, end_date))
  ensure
    @session.wait_for_user
    @session.quit
  end

  private

  def navigate_to_expense
    click(:tab_link)
    # 経費精算の入力エリアが表示されるまで待つ
    wait_until(timeout: 30) { displayed?(:form_area) }
  rescue StandardError => e
    raise "Failed to navigate to expense page: #{e.message}"
  end

  def target_dates(start_date, end_date)
    weekdays = @expense.fetch('weekdays', DEFAULT_WEEKDAYS)
    (start_date..end_date).select { |date| weekdays.include?(date.wday) }
  end

  # 明細ダイアログを一度だけ開き、「続けて入力」で対象日を連続入力する。
  def input_expenses(dates)
    if dates.empty?
      puts 'No target dates.'
      return
    end

    open_dialog
    dates.each_with_index do |date, index|
      input_detail(date, first: index.zero?)
      submit(last: index == dates.size - 1)
      puts "#{date}:Success"
    rescue StandardError => e
      puts "#{date}:Failure"
      puts e
    end
  end

  def open_dialog
    click(:add_button)
    wait_until { find(:dialog).displayed? }
  end

  def input_detail(date, first:)
    fill(:date_input, date.strftime(@expense.fetch('date_format', DEFAULT_DATE_FORMAT)))
    select_item

    # 費目に交通費を選択すると経路の入力欄が表示される。
    wait_until { find(:from_input).displayed? }
    fill(:from_input, @expense.fetch('from'))
    fill(:to_input, @expense.fetch('to'))

    # 片道／往復の切り替えボタンを押して往復にする。
    # 「続けて入力」では往復の状態が引き継がれるため、2件目以降は押さない。
    click(:round_trip_button) if first

    # 金額は経路検索で自動算出されるため、こちらでは入力しない。
    click(:search_button)

    # ローディングが消えて検索結果が出たら確定する。
    wait_for_loading
    click(:search_result_ok)
  end

  def select_item
    element = find(:item)
    Selenium::WebDriver::Support::Select.new(element).select_by(:text, @expense.fetch('item', '交通費'))
  end

  def submit(last:)
    click(:continue_button)
    sleep 0.5
    confirm = find_all(:confirm_button)
    confirm.first.click if confirm.first&.displayed?
    close_dialog if last
  end

  def close_dialog
    return unless displayed?(:dialog)

    @driver.action.send_keys(:escape).perform
    wait_until { !displayed?(:dialog) }
  end

  def fill(key, value)
    input = find(key)
    input.clear
    input.send_keys(value)
    input.send_keys(:tab)
  end

  def wait_for_loading
    begin
      wait_until(timeout: 3) { displayed?(:loading) }
    rescue Selenium::WebDriver::Error::TimeoutError
      nil
    end
    wait_until { !displayed?(:loading) }
  end
end

config = YAML.load_file('config.yml')

# 締め期間の開始日・終了日は config で指定する（既定: 昨月21日 〜 今月20日）。
expense    = config.fetch('expense', {})
start_day  = expense.fetch('start_day', 21)
end_day    = expense.fetch('end_day', 20)
start_date = (Date.today - 1.month).change(day: start_day)
end_date   = Date.today.change(day: end_day)

puts "対象期間: #{start_date} 〜 #{end_date}"

begin
  ExpenseInputter.new(config).run(start_date, end_date)
rescue StandardError => e
  puts e.message
  exit 1
end
