FROM bitwalker/alpine-elixir-phoenix:1.11.3

RUN apk add --update \
    postgresql-libs \
    postgresql-client 

RUN mkdir /ret
WORKDIR /ret

COPY . .

CMD ["/ret/scripts/entrypoint.sh"]