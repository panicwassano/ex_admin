Code.ensure_compiled(ExAdmin.Utils)
defmodule ExAdmin.Theme.ActiveAdmin.Filter do
  @moduledoc false
  require Logger
  require Ecto.Query
  import ExAdmin.Utils
  import ExAdmin.Gettext
  import ExAdmin.Filter
  use Xain

  def theme_filter_view(conn, defn, q, order, scope) do
    markup safe: true do
      div "#filters_sidebar_sectionl.sidebar_section.panel" do
        h3 (gettext "Filters")
        div ".panel_contents" do
          form "accept-charset": "UTF-8", action: admin_resource_path(conn, :index), class: "filter_form", id: "q_search", method: "get" do
            if scope do
              input type: :hidden, name: :scope, value: scope
            end
            for field <- fields(defn), do: build_field_with_values(field, q, defn)
            for field <- associations(defn), do: build_field(field, q, defn)
            div ".buttons" do
              input name: "commit", type: "submit", value: (gettext "Filter")
              a ".clear_filters_btn Clear Filters", href: "#"
              order_value = if order, do: order, else: "id_desc"
              input id: "order", name: "order", type: :hidden, value: order_value
            end
          end
        end
      end
    end

  end

  def build_field_with_values({name, type}, q, %{index_filter_values: %{} = values} = defn) do
    if !Map.has_key?(values, name) do
      build_field({name, type}, q, defn)
    else
      name_label = field_label(name, defn)
      {:ok, values} = Map.fetch(values, name)
      values = prepare_field_values(values)
      selected_key = case q["#{name}_equals"] do
        nil -> nil
        val -> val
      end

      div ".filter_form_field.filter_string" do
        label ".label #{name_label}", for: "#{name}_string"
        select "#{name}", [name: "q[#{name}_equals]"] do
          option "Any", [{:value, ""}]
          for {option_value, option_label} <- values do
            selected = if "#{option_value}" == selected_key, do: [selected: :selected], else: []
            option option_label, [{:value, "#{option_value}"} | selected]
          end
        end
      end
    end
  end

  def build_field_with_values(field, q, defn), do: build_field(field, q, defn)

  defp prepare_field_values(values) do
    Enum.map(values, &prepare_field_value/1)
  end

  defp prepare_field_value({_, _} = value), do: value
  defp prepare_field_value(value), do: {value, ExAdmin.Utils.humanize(value)}

  def build_field({name, :string}, q, defn) do
    name_label = field_label(name, defn)
    selected_name = string_selected_name(name, q)
    value = get_string_value name, q
    div ".filter_form_field.filter_string" do
      label ".label #{name_label}", for: "#{name}_numeric"
      select onchange: ~s|document.getElementById("#{name}_string").name="q[" + this.value + "]";| do
        for {suffix, text} <- string_options() do
          build_option(text, "#{name}_#{suffix}", selected_name)
        end
      end
      input id: "#{name}_string", name: "q[#{selected_name}]", type: "text", value: value
    end
  end

  def build_field({name, type}, q, defn) when type in [Ecto.DateTime, Ecto.Date, Ecto.Time, Timex.Ecto.DateTime, Timex.Ecto.Date, Timex.Ecto.Time, Timex.Ecto.DateTimeWithTimezone, NaiveDateTime, :naive_datetime] do
    name_label = field_label(name, defn)
    gte_value = get_value("#{name}_gte", q)
    lte_value = get_value("#{name}_lte", q)
    div ".filter_form_field.filter_date_range" do
      label ".label #{name_label}", for: "q_#{name}_gte"
      input class: "datepicker", id: "q_#{name}_gte", max: "10", name: "q[#{name}_gte]", size: "12", type: :text, value: gte_value
      span ".seperator -"
      input class: "datepicker", id: "q_#{name}_lte", max: "10", name: "q[#{name}_lte]", size: "12", type: :text, value: lte_value
    end
  end

  def build_field({name, num}, q, defn) when num in [:integer, :id, :decimal, :float] do
    unless check_and_build_association(name, q, defn) do
      name_label = field_label(name, defn)
      value = get_integer_value name, q
      div ".filter_form_field.filter_select" do
        label ".label #{name_label}", for: "q_#{name}"
        input "##{name}", [name: "q[#{name}_eq]", value: value]
      end
    end
  end

  def build_field({name, :scope}, q, defn) do
    unless check_and_build_association(name, q, defn) do
      name_label = field_label(name, defn)
      value = get_value("#{name}_scope", q)
      div ".filter_form_field.filter_select" do
        label ".label #{name_label}", for: "q_#{name}"
        input "##{name}", [name: "q[#{name}_scope]", value: value]
      end
    end
  end


  def build_field({name, %Ecto.Association.BelongsTo{related: assoc, owner_key: owner_key}}, q, defn) do
    id = "q_#{owner_key}"
    name_label = field_label(name, defn)
    if assoc.__schema__(:type, :name) do
      resources = filter_resources(name, assoc, defn)
      selected_key = case q["#{owner_key}_eq"] do
        nil -> nil
        val -> val
      end
      div ".filter_form_field.filter_select" do
        title = name_label |> String.replace(" Id", "")
        label ".label #{title}", for: "q_#{owner_key}"
        select "##{id}", [name: "q[#{owner_key}_eq]"] do
          option "Any", value: ""
          for r <- resources do
            id = ExAdmin.Schema.get_id(r)
            name = ExAdmin.Helpers.display_name(r)
            selected = if "#{id}" == selected_key, do: [selected: :selected], else: []
            option name, [{:value, "#{id}"} | selected]
          end
        end
      end
    end
  end

  def build_field({name, :boolean}, q, defn) do
    name_label = field_label(name, defn)
    name_field = "#{name}_eq"
    opts = [id: "q_#{name}", name: "q[#{name_field}]", type: :checkbox, value: "true"]
    new_opts = if q do
      if Map.get(q, name_field, nil), do: [{:checked, :checked} | opts], else: opts
    else
      opts
    end
    div ".filter_form_field.filter_boolean" do
      label ".label #{name_label}", for: "q_#{name}"
      input new_opts
    end
  end

  def build_field({name, Ecto.UUID}, q, defn) do
    name_label = field_label(name, defn)
    value = get_string_value name, q

    div ".filter_form_field.filter_select" do
      label ".label #{name_label}", for: "q_#{name}"
      input "##{name}", [name: "q[#{name}_uuideq]", value: value]
    end
  end

  def build_field({name, type}, _q, _) do
    Logger.debug "ExAdmin.Filter: unknown type: #{inspect type} for field: #{inspect name}"
    nil
  end


end
