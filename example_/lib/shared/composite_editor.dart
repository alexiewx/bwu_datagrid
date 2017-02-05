library bwu_datagrid_examples.shared.composite_editor;

import 'dart:html' as dom;
import 'dart:math' as math;

import 'package:bwu_datagrid/core/core.dart' show ItemBase;
import 'package:bwu_datagrid/datagrid/helpers.dart' show Column, NodeBox;
import 'package:bwu_datagrid/editors/editors.dart'
    show Editor, EditorArgs, ValidationErrorSource, ValidationResult;

class CompositeEditorOptions {
  String validationFailedMsg;
  Function show;
  Function hide;
  Function position;
  Function destroy;

  CompositeEditorOptions(
      {this.validationFailedMsg: 'Some of the fields have failed validation',
      this.show,
      this.hide,
      this.position,
      this.destroy});
}

/// A composite Bwu Datagrid editor factory.
/// Generates an editor that is composed of multiple editors for given columns.
/// Individual editors are provided given containers instead of the original cell.
/// Validation will be performed on all editors individually and the results will be aggregated into one
/// validation result.
///
///
/// The returned editor will have its prototype set to CompositeEditor, so you can use the "instanceof" check.
///
/// NOTE:  This doesn't work for detached editors since they will be created and positioned relative to the
///        active cell and not the provided container.
///
/// @param columns {Array} Column definitions from which editors will be pulled.
/// @param containers {Array} Container HTMLElements in which editors will be placed.
/// @param options {Object} Options hash:
///  validationFailedMsg     -   A generic failed validation message set on the aggregated validation resuls.
///  hide                    -   A function to be called when the grid asks the editor to hide itself.
///  show                    -   A function to be called when the grid asks the editor to show itself.
///  position                -   A function to be called when the grid asks the editor to reposition itself.
///  destroy                 -   A function to be called when the editor is destroyed.
class CompositeEditor extends Editor {
  List<Column> columns;
  CompositeEditorOptions options;
  Map<String, dom.Element> containers;

  CompositeEditor(this.args);
  CompositeEditor.prepare(this.columns, this.containers, this.options);

  Editor firstInvalidEditor;

  EditorArgs args;
  List<Editor> editors;

  NodeBox getContainerBox(String id) {
    final dom.Element container = containers[id];
    math.Rectangle<int> offset = container.offset as math.Rectangle<int>;
    final int w = container.offsetWidth.round();
    final int h = container.offsetHeight.round();

    return new NodeBox(
        top: offset.top.round(),
        left: offset.left.round(),
        bottom: offset.top.round() + h,
        right: offset.left.round() + w,
        width: w,
        height: h,
        visible: true);
  }

  void init() {
    int idx = columns.length;
    editors = new List<Editor>(columns.length);
    EditorArgs newArgs;
    while (idx-- > 0) {
      if (columns[idx].editor != null) {
        //newArgs = $.extend({}, args);
        newArgs = new EditorArgs(
            container: containers[columns[idx].id],
            column: columns[idx],
            position: getContainerBox(columns[idx].id));

        editors[idx] = columns[idx].editor.newInstance(newArgs);
      }
    }
  }

  @override
  void destroy() {
    int idx = editors.length;
    while (idx-- > 0) {
      editors[idx].destroy();
    }

    if (options.destroy != null) options.destroy();
  }

  @override
  void focus() {
    // if validation has failed, set the focus to the first invalid editor
    if (firstInvalidEditor != null) {
      firstInvalidEditor.focus();
    } else {
      editors[0].focus();
    }
  }

  @override
  bool get isValueChanged {
    int idx = editors.length;
    while (idx-- > 0) {
      if (editors[idx].isValueChanged) {
        return true;
      }
    }
    return false;
  }

  @override
  dynamic serializeValue() {
    final List<String> serializedValue = new List<String>(columns.length);
    int idx = editors.length;
    while (idx-- > 0) {
      serializedValue[idx] = editors[idx].serializeValue() as String;
    }
    return serializedValue;
  }

  @override
  void applyValue(ItemBase item, dynamic state) {
    assert(state is List);
    int idx = editors.length;
    while (idx-- > 0) {
      editors[idx].applyValue(item, state[idx]);
    }
  }

  @override
  void loadValue(ItemBase item) {
    int idx = editors.length;
    while (idx-- > 0) {
      editors[idx].loadValue(item);
    }
  }

  @override
  ValidationResult validate() {
    ValidationResult validationResults;
    List<ValidationErrorSource> errors = <ValidationErrorSource>[];

    firstInvalidEditor = null;

    int idx = editors.length;
    while (idx-- > 0) {
      validationResults = editors[idx].validate();
      if (!validationResults.isValid) {
        firstInvalidEditor = editors[idx];
        errors.add(new ValidationErrorSource(
            index: idx,
            editor: editors[idx],
            container: containers[idx],
            message: validationResults.message));
      }
    }

    if (errors.length > 0) {
      return new ValidationResult(false, options.validationFailedMsg, errors);
    } else {
      return new ValidationResult(true);
    }
  }

  @override
  void hide() {
    int idx = editors.length;
    while (idx-- > 0) {
      if (editors[idx].hide != null) editors[idx].hide();
    }
    if (options.hide != null) options.hide();
  }

  @override
  void show() {
    int idx = editors.length;
    while (idx-- > 0) {
      if (editors[idx].show != null) editors[idx].show();
    }
    if (options.show != null) options.show();
  }

  @override
  void position(NodeBox box) {
    if (options.position != null) options.position(box);
  }

  @override
  Editor newInstance(EditorArgs args) {
    return this;
  }
}