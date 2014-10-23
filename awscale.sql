CREATE DATABASE awscale;
GRANT ALL PRIVILEGES on awscale.* TO 'awscaleuser'@'%' IDENTIFIED BY 'awscalepass';
USE awscale;
CREATE TABLE cluster_members (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  instance_id CHAR(20) NOT NULL,
  name CHAR(20) NOT NULL,
  private_dns_name CHAR(100) NOT NULL,
  public_dns_name CHAR(100) NOT NULL,
  az CHAR(20) NOT NULL,
  security_group CHAR(20) NOT NULL,
  ami CHAR(20) NOT NULL,
  instance_type CHAR(20) NOT NULL,
  group_name CHAR(20) NOT NULL,
  elb_name CHAR(100),
  status CHAR(20) NOT NULL,
  created_date CHAR(30) NOT NULL,
  updated_date CHAR(30) NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE counter (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  group_name CHAR(20) NOT NULL,
  elb_dns_name CHAR(100),
  count INT NOT NULL,
  basic_count INT NOT NULL,
  max_count INT NOT NULL,
  created_date CHAR(20) NOT NULL,
  updated_date CHAR(20) NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE health (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  group_name CHAR(20) NOT NULL,
  elb_dns_name CHAR(100),
  healthy_threshold INT NOT NULL,
  unhealthy_threshold INT NOT NULL,
  healthy_count INT NOT NULL,
  count INT,
  time_count INT,
  created_date CHAR(20) NOT NULL,
  updated_date CHAR(20) NOT NULL,
  PRIMARY KEY (id)
);
