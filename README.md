# limpa_logs_traces_audits

Limpa logs, traces, audits, incidentes e core dumps de todos os ORACLE_HOMEs de um usuário.

## Requisitos

* Criar diretórios

  ```bash
  mkdir -p /home/oracle/scripts/limpa_logs_traces_audits/logrotate
  ```

* Copiar os arquivos desta pasta para a pasta no servidor

* Conceder permissão de execução

  ```bash
  chmod 700 /home/oracle/scripts/limpa_logs_traces_audits/limpa_logs_traces_audits.sh
  chmod 700 /home/oracle/scripts/limpa_logs_traces_audits/gen_logrotate_config.sh
  chmod 700 /home/oracle/scripts/limpa_logs_traces_audits/logrotate_manual.sh
  chmod 700 /home/oracle/scripts/limpa_logs_traces_audits/retencao.sh
  ```

* logrotate disponivel no `PATH` (desejável)

* Incluir entrada na crontab, conforme arquivo [entrada_crontab.txt](entrada_crontab.txt)
  Caso haja multiplos owners de ORACLE_HOMEs, é necessario agendar a rotina na crontab de cada usuário.

* Variáveis de ambiente definidas no arquivo `${HOME}/.bash_profile`

* Definir no script retencao.sh os prazos de retenção de cada tipo de arquivo
