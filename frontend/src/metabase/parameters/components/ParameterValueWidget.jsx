/* eslint "react/prop-types": "warn" */

import React, { Component } from "react";
import PropTypes from "prop-types";
import { connect } from "react-redux";
import { t } from "ttag";

import PopoverWithTrigger from "metabase/components/PopoverWithTrigger";
import Icon from "metabase/components/Icon";
import DateSingleWidget from "./widgets/DateSingleWidget";
import DateRangeWidget from "./widgets/DateRangeWidget";
import DateRelativeWidget from "./widgets/DateRelativeWidget";
import DateMonthYearWidget from "./widgets/DateMonthYearWidget";
import DateQuarterYearWidget from "./widgets/DateQuarterYearWidget";
import DateAllOptionsWidget from "./widgets/DateAllOptionsWidget";
import CategoryWidget from "./widgets/CategoryWidget";
import TextWidget from "./widgets/TextWidget";
import ParameterFieldWidget from "./widgets/ParameterFieldWidget";

import { fetchField, fetchFilterFieldValues } from "metabase/redux/metadata";
import {
  getMetadata,
  makeGetMergedParameterFieldValues,
} from "metabase/selectors/metadata";

import { getParameterIconName } from "metabase/meta/Parameter";

import S from "./ParameterWidget.css";

import cx from "classnames";
import _ from "underscore";

const DATE_WIDGETS = {
  "date/single": DateSingleWidget,
  "date/range": DateRangeWidget,
  "date/relative": DateRelativeWidget,
  "date/month-year": DateMonthYearWidget,
  "date/quarter-year": DateQuarterYearWidget,
  "date/all-options": DateAllOptionsWidget,
};

const makeMapStateToProps = () => {
  const getMergedParameterFieldValues = makeGetMergedParameterFieldValues();
  const mapStateToProps = (state, props) => ({
    metadata: getMetadata(state),
    values: getMergedParameterFieldValues(state, props),
  });
  return mapStateToProps;
};

const mapDispatchToProps = {
  fetchFilterFieldValues,
  fetchField,
};

@connect(
  makeMapStateToProps,
  mapDispatchToProps,
)
export default class ParameterValueWidget extends Component {
  static propTypes = {
    parameter: PropTypes.object.isRequired,
    name: PropTypes.string,
    value: PropTypes.any,
    setValue: PropTypes.func.isRequired,
    placeholder: PropTypes.string,
    isEditing: PropTypes.bool,
    noReset: PropTypes.bool,
    commitImmediately: PropTypes.bool,
    focusChanged: PropTypes.func,
    isFullscreen: PropTypes.bool,
    className: PropTypes.string,

    // provided by @connect
    values: PropTypes.array,
    metadata: PropTypes.object.isRequired,
  };

  static defaultProps = {
    values: [],
    isEditing: false,
    noReset: false,
    commitImmediately: false,
    className: "",
  };

  // this method assumes the parameter is associated with only one field
  getSingleField() {
    const { parameter, metadata } = this.props;
    return parameter.field_id != null
      ? metadata.fields[parameter.field_id]
      : null;
  }

  getWidget() {
    const { parameter, values } = this.props;
    if (DATE_WIDGETS[parameter.type]) {
      return DATE_WIDGETS[parameter.type];
    } else if (this.getSingleField()) {
      return ParameterFieldWidget;
    } else if (values && values.length > 0) {
      return CategoryWidget;
    } else {
      return TextWidget;
    }
  }

  state = { isFocused: false };

  componentWillMount() {
    // In public dashboards we receive field values before mounting this component and
    // without need to call `fetchFieldValues` separately
    if (_.isEmpty(this.props.values)) {
      this.updateFieldValues(this.props);
    }
  }

  fieldIds({ parameter: { field_id, field_ids = [] } }) {
    return field_id ? [field_id] : field_ids;
  }

  componentWillReceiveProps(nextProps) {
    if (!_.isEqual(this.fieldIds(this.props), this.fieldIds(nextProps))) {
      this.updateFieldValues(nextProps);
    }
  }

  _getPosFilter(parameters, fieldId) {
    let paramIndex;
    parameters.forEach((param,i) => {
      if (param.field_ids[0] === fieldId) {
        paramIndex = i;
        return;
      }
    });
    return paramIndex;
  }

  _castInt(strToCast) {
    console.log('strToCast', strToCast);
    console.log('find -', strToCast.includes("-"));
    return parseInt(strToCast) && !strToCast.includes("-") ? parseInt(strToCast) : strToCast;
  }

  _genQueryFilter(parameters, posField) {
    if (posField > 0) {
      let filters = { "filter-field-values": [] };
      let urlParams = new URLSearchParams(window.location.search);
      for (var i = 0; i < posField; i++) {
        let parameter = parameters[i];
        let filterValues = urlParams.getAll(parameter.slug).map(val => this._castInt(val));
        let filter = { id: parameter.field_ids[0], values: filterValues };
        console.log('cambio');
        if (filter.id !== null && filter.values && filter.values.length > 0) {
          filters["filter-field-values"].push(filter);
        }
      }
      return filters["filter-field-values"].length > 0 ? filters : null;
    }
    return null;
  }

  updateFieldValues(props) {
    const { parameters, parameter } = props;
    const posFilter = this._getPosFilter(parameters, parameter.field_ids[0]);
    const queryFilter = this._genQueryFilter(parameters, posFilter);
    for (const id of this.fieldIds(props)) {
      props.fetchField(id);
      props.fetchFilterFieldValues(id, queryFilter);
    }
  }

  render() {
    const {
      parameter,
      parameters,
      value,
      values,
      setValue,
      isEditing,
      placeholder,
      isFullscreen,
      noReset,
      commitImmediately,
      className,
      focusChanged: parentFocusChanged,
    } = this.props;

    const hasValue = value != null;

    const Widget = this.getWidget();

    const focusChanged = isFocused => {
      if (parentFocusChanged) {
        parentFocusChanged(isFocused);
      }
      this.setState({ isFocused });
    };

    const getParameterTypeIcon = () => {
      if (!isEditing && !hasValue && !this.state.isFocused) {
        return (
          <Icon
            name={getParameterIconName(parameter.type)}
            className="flex-align-left mr1 flex-no-shrink"
            size={14}
          />
        );
      } else {
        return null;
      }
    };

    const getWidgetStatusIcon = () => {
      if (isFullscreen) {
        return null;
      }

      if (hasValue && !noReset) {
        return (
          <Icon
            name="close"
            className="flex-align-right cursor-pointer flex-no-shrink"
            size={12}
            onClick={e => {
              if (hasValue) {
                e.stopPropagation();
                setValue(null);
              }
            }}
          />
        );
      } else if (Widget.noPopover && this.state.isFocused) {
        return (
          <Icon
            name="enter_or_return"
            className="flex-align-right flex-no-shrink"
            size={12}
          />
        );
      } else if (Widget.noPopover) {
        return (
          <Icon
            name="empty"
            className="flex-align-right cursor-pointer flex-no-shrink"
            size={12}
          />
        );
      } else if (!Widget.noPopover) {
        return (
          <Icon
            name="chevrondown"
            className="flex-align-right flex-no-shrink"
            size={12}
          />
        );
      }
    };

    if (Widget.noPopover) {
      return (
        <div
          className={cx(S.parameter, S.noPopover, className, {
            [S.selected]: hasValue,
            [S.isEditing]: isEditing,
          })}
        >
          {getParameterTypeIcon()}
          <Widget
            placeholder={placeholder}
            parameters={parameters}
            value={value}
            values={values}
            field={this.getSingleField()}
            setValue={setValue}
            isEditing={isEditing}
            commitImmediately={commitImmediately}
            focusChanged={focusChanged}
          />
          {getWidgetStatusIcon()}
        </div>
      );
    } else {
      const placeholderText = isEditing
        ? t`Select a default value…`
        : placeholder || t`Select…`;

      return (
        <PopoverWithTrigger
          ref="valuePopover"
          triggerElement={
            <div
              ref="trigger"
              className={cx(S.parameter, className, { [S.selected]: hasValue })}
            >
              {getParameterTypeIcon()}
              <div className="mr1 text-nowrap">
                {hasValue ? Widget.format(value, values) : placeholderText}
              </div>
              {getWidgetStatusIcon()}
            </div>
          }
          target={() => this.refs.trigger} // not sure why this is necessary
          // make sure the full date picker will expand to fit the dual calendars
          autoWidth={parameter.type === "date/all-options"}
        >
          <Widget
            value={value}
            values={values}
            setValue={setValue}
            onClose={() => this.refs.valuePopover.close()}
          />
        </PopoverWithTrigger>
      );
    }
  }
}
