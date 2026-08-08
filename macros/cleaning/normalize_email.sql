{% macro normalize_email(column_name) %}
LOWER(TRIM({{ column_name }}))
{% endmacro %}