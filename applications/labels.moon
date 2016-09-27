lapis = require "lapis"
db = require "lapis.db"

import
  assert_csrf
  assert_editable
  require_login
  capture_errors_404
  from require "helpers.app"

import paginated_modules from require "helpers.modules"
import trim_filter from require "lapis.util"
import assert_valid from require "lapis.validate"

import load_module from require "helpers.loaders"

import
  capture_errors
  respond_to
  assert_error
  from require "lapis.application"


class MoonRocksLabels extends lapis.Application
  [label: "/labels/:label"]: capture_errors_404 =>
    import ApprovedLabels, Modules from require "models"

    trim_filter @params
    assert_valid @params, {
      {"label", type: "string", exists: true}
    }

    @approved_label = ApprovedLabels\find name: @params.label

    @title = "Modules labeled '#{@params.label}'"

    pager = Modules\paginated "
      where ? && labels and labels is not null
    ", db.array {
      @params.label
    }

    paginated_modules @, pager, {
      per_page: 50
      fields: "id, name, display_name, user_id, downloads, summary"
    }

    status = unless next @modules then 404
    render: true, :status

  [add_label: "/label/add/:user/:module"]: capture_errors_404 require_login respond_to {
    before: =>
      load_module @
      assert_editable @, @module

      import ApprovedLabels from require "models"

      @title = "Add Label to Module"

      already_in = { l, true for l in *@module.labels or {} }
      @labels = for l in *ApprovedLabels\select "order by name"
        continue if already_in[l.name]
        l

    GET: =>
      render: true

    POST: capture_errors =>
      assert_csrf @

      assert_valid @params, {
        { "label", exists: true }
      }

      label = assert_error Labels\find(id: @params.label_id), "Invalid label id"

      assert_error ModuleLabels\create label_id: label.id, module_id: @module.id
      redirect_to: @url_for("module", @)
  }

  [remove_label: "/label/remove/:user/:module/:label_id"]: capture_errors_404 require_login respond_to {
    before: =>
      load_module @
      assert_editable @, @module

      assert_valid @params, {
        {"label_id", is_integer: true}
      }

      @label = assert_error Labels\find(@params.label_id), "invalid label"

      assert_error ModuleLabels\find({
        label_id: @label.id
        module_id: @module.id
      }), "Module does not have this label"

    GET: =>
      @title = "Remove Label"
      render: true

    POST: =>
      assert_csrf @

      ModuleLabels\remove @label, @module
      redirect_to: @url_for(@module)
  }


