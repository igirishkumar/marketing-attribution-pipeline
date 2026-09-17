{% macro safe_divide(numerator, denominator) %}
    {% if target.type == 'bigquery' %}
        SAFE_DIVIDE({{ numerator }}, {{ denominator }})
    {% else %}
        CASE
            WHEN {{ denominator }} IS NULL
                OR {{ denominator }} = 0
            THEN NULL
            ELSE {{ numerator }} / {{ denominator }}
        END
    {% endif %}
{% endmacro %}