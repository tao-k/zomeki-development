# encoding: utf-8
class GpCalendar::Public::Node::BaseController < Cms::Controller::Public::Base
  def pre_dispatch
    @node = Page.current_node
    @content = GpCalendar::Content::Event.find_by_id(@node.content.id)
    return http_error(404) unless @content

    @today = Date.today
    @min_date = 1.year.ago(@today.beginning_of_month)
    @max_date = 11.months.since(@today.beginning_of_month)

    return http_error(404) unless validate_date

    # These params are used in pieces
    params[:gp_calendar_event_date]     = @date
    params[:gp_calendar_event_min_date] = @min_date
    params[:gp_calendar_event_max_date] = @max_date
  end

  private

  def validate_date
    @month = params[:month].to_i
    @month = @today.month if @month.zero?
    return false unless @month.between?(1, 12)

    @year = params[:year].to_i
    @year = @today.year if @year.zero?
    return false unless @year.between?(1900, 2100)

    @date = Date.new(@year, @month, 1)
    return @date.between?(@min_date, @max_date)
  end

  def event_docs(start_date, end_date)
    doc_contents = Cms::ContentSetting.where(name: 'gp_calendar_content_event_id', value: @content.id).map(&:content)
    doc_contents.select! {|dc| dc.site == Page.site }
    return [] if doc_contents.empty?

    doc_contents.map {|dc|
      case dc.model
      when 'GpArticle::Doc'
        dc = GpArticle::Content::Doc.find(dc.id)
        docs = dc.public_docs.table
        dc.public_docs.where(event_state: 'visible').where(docs[:event_date].gteq(start_date).and(docs[:event_date].lteq(end_date)))
      else
        []
      end
    }.flatten
  end

  def merge_docs_into_events(docs, events)
    docs.each do |doc|
      event = GpCalendar::Event.new(title: doc.title, href: doc.public_uri, target: '_self',
                                    started_on: doc.event_date, ended_on: doc.event_date, description: doc.summary)
      event.categories = doc.categories
      event.files = doc.files
      events << event
    end
    events.sort! {|a, b| a.started_on <=> b.started_on }
  end

  def find_category_by_specified_path(path)
    return nil unless path.kind_of?(String)
    category_type_name, category_path = path.split('/', 2)
    category_type = @content.category_types.find_by_name(category_type_name)
    return nil unless category_type
    category_type.find_category_by_path_from_root_category(category_path)
  end
end