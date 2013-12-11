create database sigma;

CREATE USER 'sigma_admin'@'localhost' IDENTIFIED BY 'admin';
CREATE USER 'sigma_admin'@'%' IDENTIFIED BY 'admin';
CREATE USER 'sigma_user'@'localhost' IDENTIFIED BY 'user';
CREATE USER 'sigma_user'@'%' IDENTIFIED BY 'user';
CREATE USER 'sigma_query'@'localhost' IDENTIFIED BY 'query';
CREATE USER 'sigma_query'@'%' IDENTIFIED BY 'query';

GRANT ALL PRIVILEGES ON sigma.* TO 'sigma_admin'@'localhost';
GRANT ALL PRIVILEGES ON sigma.* TO 'sigma_admin'@'%';
GRANT SELECT, INSERT, UPDATE ON sigma.* TO 'sigma_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON sigma.* TO 'sigma_user'@'%';
GRANT SELECT ON sigma.* TO 'sigma_query'@'localhost';
GRANT SELECT ON sigma.* TO 'sigma_query'@'%';

FLUSH PRIVILEGES;
