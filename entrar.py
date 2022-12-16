# -*- coding: utf-8 -*-
"""
Se realiza n Python3 y Selenium junto con Firefox
"""
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.firefox.options import Options

from selenium import webdriver
from webdriver_manager.firefox import GeckoDriverManager

driver = webdriver.Firefox(executable_path=GeckoDriverManager().install())

# opts = Options()
# opts.add_argument("user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/71.0.3578.80 Chrome/71.0.3578.80 Safari/537.36")

driver.get('https://twitter.com/login')

user = "usuario"
password = open('clave.txt').readline().strip()


# Esperar que aparezca 
input_user = WebDriverWait(driver, 10).until(
  EC.presence_of_element_located((By.XPATH, '//input[@name="session[username_or_email]"]'))
)
# Obtener los inputs de usuario y password
input_pass = driver.find_element(By.XPATH, '//input[@name="session[password]"]')

# Escribo usuario input
input_user.send_keys(user)

# Escribo mi contrasena en el input
input_pass.send_keys(password)

# Obtengo el boton de login
login_button = driver.find_element(By.XPATH, '//main//div[@data-testid="LoginForm_Login_Button"]/div[@dir="auto"]')
# Le doy click
login_button.click()

# Espero a que aparezcan los tweets
# tweets = WebDriverWait(driver, 10).until(
#  EC.presence_of_all_elements_located((By.XPATH, '//section//article//div[@lang="en"]')) # Este xpath podria ser mejor
# )

# Imprimo el texto de los tweets
for tweet in tweets:
  print(tweet.text)
