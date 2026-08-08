{% macro normalize_phone(column_name) %}

REGEXP_REPLACE({{ column_name }}, r'[^0-9]', '')

{% endmacro %}